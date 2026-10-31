import Foundation
import GameTimeServices

/// A client that buffers events and can be asked to send them now, for example when the app goes to
/// the background.
public protocol AnalyticsFlushing: Sendable {
    func flush()
}

/// Stamps events with the common fields, keeps them on the device, and forwards them to any
/// `AnalyticsClient` **only while sharing is enabled**.
///
/// Identity is a random install id made on first launch. It is not derived from the device, the
/// player or any advertising identifier, and it disappears when the app is deleted.
///
/// The pipeline emits `first_open`, `session_start` and `session_end` itself. Games send everything
/// else through `track(_:)` with their own typed, versioned schema. It is itself an `AnalyticsClient`,
/// so code written against that protocol can be handed the pipeline directly.
public final class AnalyticsPipeline: AnalyticsClient, @unchecked Sendable {
    public struct Context: Sendable, Equatable {
        /// The game's slug, such as `top-off`. Every game shares one analytics project, so this is how
        /// dashboards tell them apart.
        public var game: String
        public var appVersion: String
        public var build: String
        public var idiom: String
        public var osMajor: String
        public var language: String
        /// The game's event schema version, stamped on every event as `schema`.
        public var schemaVersion: Int

        public init(game: String, appVersion: String, build: String, idiom: String, osMajor: String, language: String, schemaVersion: Int) {
            self.game = game
            self.appVersion = appVersion
            self.build = build
            self.idiom = idiom
            self.osMajor = osMajor
            self.language = language
            self.schemaVersion = schemaVersion
        }
    }

    /// The property keys the pipeline stamps on every event. Game schemas include these in their
    /// allow-lists.
    public static let commonPropertyKeys: Set<String> = [
        "game", "schema", "app_version", "build", "install_id", "session_id", "seq", "ts", "platform", "idiom", "os_major", "lang"
    ]

    /// A gap longer than this between leaving and returning starts a new session.
    public static let sessionGap: TimeInterval = 30 * 60

    private struct Keys {
        let installID: String
        let sharing: String
        let seq: String
        let session: String
        let attempts: String

        init(prefix: String) {
            installID = "\(prefix).installID"
            sharing = "\(prefix).sharing"
            seq = "\(prefix).seq"
            session = "\(prefix).session"
            attempts = "\(prefix).attempts"
        }
    }

    private struct SessionState: Codable {
        var id: String
        var startedAt: Date
        var lastActive: Date
        var levelsCompleted: Int
    }

    private let queue = DispatchQueue(label: "ai.knowlly.gametime.analytics", qos: .utility)
    private let store: any EventStoring
    private let clients: [any AnalyticsClient]
    private let context: Context
    private let defaults: UserDefaults
    private let keys: Keys
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> String

    private var installID: String
    private var seq: Int
    private var session: SessionState?
    private var sharing: Bool

    /// - Parameters:
    ///   - keyPrefix: namespaces this game's saved state in `UserDefaults`, such as `topoff.analytics`.
    ///   - sharingByDefault: whether events are forwarded to `clients` before the player has made a
    ///     choice. Once `setSharingEnabled(_:)` is called, the player's choice is kept.
    ///   - predatesAnalytics: true when this install was already being played before the pipeline was
    ///     added (a live game gaining analytics in an update). Its first pipeline launch then starts a
    ///     session but records no `first_open`, so updating players are not counted as new ones.
    ///   - suiteName: picks a defaults suite (tests use their own); nil means the standard defaults.
    public init(
        store: any EventStoring,
        clients: [any AnalyticsClient] = [],
        context: Context,
        keyPrefix: String,
        sharingByDefault: Bool = false,
        predatesAnalytics: Bool = false,
        suiteName: String? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        let defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        let keys = Keys(prefix: keyPrefix)
        self.store = store
        self.clients = clients
        self.context = context
        self.defaults = defaults
        self.keys = keys
        self.now = now
        self.makeID = makeID
        self.installID = defaults.string(forKey: keys.installID) ?? makeID()
        self.seq = defaults.integer(forKey: keys.seq)
        self.sharing = defaults.object(forKey: keys.sharing) == nil ? sharingByDefault : defaults.bool(forKey: keys.sharing)
        self.session = defaults.data(forKey: keys.session).flatMap { try? JSONDecoder().decode(SessionState.self, from: $0) }
        let isFirstLaunch = defaults.string(forKey: keys.installID) == nil
        defaults.set(installID, forKey: keys.installID)
        if isFirstLaunch {
            let date = now()
            queue.async { [self] in
                ensureSession(at: date)
                if !predatesAnalytics { emit(name: "first_open", properties: [:], at: date) }
            }
        }
    }

    // MARK: Public API

    public var isSharingEnabled: Bool { queue.sync { sharing } }

    /// Turns forwarding to analytics clients on or off, and remembers the choice.
    public func setSharingEnabled(_ enabled: Bool) {
        queue.sync {
            sharing = enabled
            defaults.set(enabled, forKey: keys.sharing)
        }
    }

    public func track(_ event: AnalyticsEvent) {
        // Read the clock now, not when the queue gets round to it: an event belongs to the moment it happened.
        let date = now()
        queue.async { [self] in
            ensureSession(at: date)
            emit(name: event.name, properties: event.properties, at: date)
        }
    }

    /// Call when the app becomes active. Starts a session, or continues the current one.
    public func appDidBecomeActive() {
        let date = now()
        queue.async { [self] in ensureSession(at: date) }
    }

    /// Call when the app goes to the background. The session is closed later if the player stays
    /// away, and buffering clients are asked to send what they hold while the app can still run.
    public func appDidEnterBackground() {
        let date = now()
        queue.async { [self] in
            if var session {
                session.lastActive = date
                self.session = session
                persistSession()
            }
            for case let client as any AnalyticsFlushing in clients { client.flush() }
        }
    }

    /// Counts a start of `key` (such as `campaign:12`) and returns which attempt this is on this
    /// install, starting at 1.
    public func nextAttempt(key: String) -> Int {
        queue.sync {
            var attempts = (defaults.dictionary(forKey: keys.attempts) as? [String: Int]) ?? [:]
            attempts[key, default: 0] += 1
            defaults.set(attempts, forKey: keys.attempts)
            return attempts[key] ?? 1
        }
    }

    /// Records that a level was completed in the current session, for the session summary.
    public func noteLevelCompleted() {
        queue.async { [self] in
            session?.levelsCompleted += 1
            persistSession()
        }
    }

    public func events() -> [StoredEvent] {
        queue.sync { store.all() }
    }

    /// The log file to hand to a tester's share sheet, after pending writes have landed.
    public func exportFileURL() -> URL? {
        queue.sync { store.fileURL }
    }

    public func clearLocalEvents() {
        queue.sync { store.clear() }
    }

    /// Waits for queued work. Tests use this; the app never needs to.
    public func flush() {
        queue.sync {}
    }

    // MARK: Queue-confined

    private func ensureSession(at date: Date) {
        if var current = session {
            if date.timeIntervalSince(current.lastActive) > Self.sessionGap {
                close(current, at: current.lastActive)
                start(at: date)
            } else {
                current.lastActive = date
                session = current
                persistSession()
            }
        } else {
            start(at: date)
        }
    }

    private func start(at date: Date) {
        session = SessionState(id: makeID(), startedAt: date, lastActive: date, levelsCompleted: 0)
        persistSession()
        emit(name: "session_start", properties: [:], at: date)
    }

    private func close(_ ended: SessionState, at date: Date) {
        let duration = max(0, Int(date.timeIntervalSince(ended.startedAt)))
        emit(
            name: "session_end",
            properties: ["duration_s": String(duration), "levels_completed": String(ended.levelsCompleted)],
            at: date,
            sessionID: ended.id
        )
    }

    private func persistSession() {
        if let session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: keys.session)
        }
    }

    private func emit(name: String, properties eventProperties: [String: String], at date: Date, sessionID: String? = nil) {
        seq += 1
        defaults.set(seq, forKey: keys.seq)

        var properties = eventProperties
        properties["game"] = context.game
        properties["schema"] = String(context.schemaVersion)
        properties["app_version"] = context.appVersion
        properties["build"] = context.build
        properties["install_id"] = installID
        properties["session_id"] = sessionID ?? session?.id ?? "none"
        properties["seq"] = String(seq)
        properties["ts"] = String(Int64(date.timeIntervalSince1970 * 1000))
        properties["platform"] = "ios"
        properties["idiom"] = context.idiom
        properties["os_major"] = context.osMajor
        properties["lang"] = context.language

        store.append(StoredEvent(name: name, properties: properties))

        guard sharing else { return }
        let outgoing = AnalyticsEvent(name: name, properties: properties)
        for client in clients { client.track(outgoing) }
    }
}
