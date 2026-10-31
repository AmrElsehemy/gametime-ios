import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import GameTimeCore
import GameTimeServices

/// Where and how to send events to PostHog.
///
/// The project API key is a write-only ingestion key, so it is safe to ship inside the app. Games read
/// it from their Info.plist (`PostHogAPIKey`); a build without one attaches no client and sends nothing.
public struct PostHogConfiguration: Sendable, Equatable {
    /// PostHog Cloud EU ingestion.
    public static let euHost = URL(string: "https://eu.i.posthog.com")!

    public static let apiKeyInfoKey = "PostHogAPIKey"
    public static let hostInfoKey = "PostHogHost"

    public let apiKey: String
    public let host: URL
    /// Send once this many events are waiting.
    public var flushAt: Int
    /// Events per request.
    public var maxBatchSize: Int
    /// Oldest events are dropped beyond this, so an install that is never online cannot grow without bound.
    public var maxQueuedEvents: Int

    /// Returns nil for a missing or blank key.
    public init?(apiKey: String?, host: URL = euHost, flushAt: Int = 20, maxBatchSize: Int = 100, maxQueuedEvents: Int = 1_000) {
        guard let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty, !key.hasPrefix("$(") else {
            return nil
        }
        self.apiKey = key
        self.host = host
        self.flushAt = max(1, flushAt)
        self.maxBatchSize = max(1, maxBatchSize)
        self.maxQueuedEvents = max(self.maxBatchSize, maxQueuedEvents)
    }

    /// Reads `PostHogAPIKey` and, optionally, `PostHogHost` from an Info.plist dictionary.
    public init?(infoDictionary: [String: Any]) {
        let host = (infoDictionary[Self.hostInfoKey] as? String)
            .flatMap { $0.isEmpty ? nil : URL(string: $0) } ?? Self.euHost
        self.init(apiKey: infoDictionary[Self.apiKeyInfoKey] as? String, host: host)
    }

    var batchURL: URL { host.appendingPathComponent("batch").appendingPathComponent("") }
}

public enum AnalyticsDeliveryResult: Sendable, Equatable {
    case delivered
    /// Offline, rate limited or a server error: keep the events and try again later.
    case retryLater
    /// The request itself was rejected: retrying would fail the same way, so drop the events.
    case rejected
}

public protocol AnalyticsHTTPTransport: Sendable {
    func post(_ body: Data, to url: URL) async -> AnalyticsDeliveryResult
}

public struct URLSessionAnalyticsTransport: AnalyticsHTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func post(_ body: Data, to url: URL) async -> AnalyticsDeliveryResult {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        do {
            let (_, response) = try await session.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode else { return .retryLater }
            return Self.result(forStatus: status)
        } catch {
            return .retryLater
        }
    }

    static func result(forStatus status: Int) -> AnalyticsDeliveryResult {
        switch status {
        case 200..<300: .delivered
        case 408, 429, 500...: .retryLater
        default: .rejected
        }
    }
}

/// Sends pipeline events to PostHog's batch endpoint, with no PostHog SDK linked.
///
/// Privacy defaults, set on every event:
/// - `distinct_id` is the pipeline's random install id; nothing identifies the device or the player.
/// - `$process_person_profile: false`: no person profiles are created, events stay anonymous.
/// - `$geoip_disable: true`: PostHog does not derive a location from the request's IP address.
///
/// Events wait in a small file-backed queue, so they survive the app being closed while offline.
/// Every event has a stable `uuid`, which PostHog uses to deduplicate a batch that is retried after
/// a lost response. Failures never reach the player.
public final class PostHogAnalyticsClient: AnalyticsClient, AnalyticsFlushing, @unchecked Sendable {
    struct QueuedEvent: Codable, Equatable {
        let uuid: String
        let name: String
        let properties: [String: String]
    }

    /// Pipeline fields that PostHog records natively, so they are not repeated as properties.
    private static let omittedKeys: Set<String> = ["install_id", "ts"]

    private let configuration: PostHogConfiguration
    private let transport: any AnalyticsHTTPTransport
    private let queueFileURL: URL?
    private let clock: any GameTimeClock
    private let makeUUID: @Sendable () -> String

    private let lock = NSLock()
    private var pending: [QueuedEvent]
    private var sending: Task<Void, Never>?
    private var failures = 0
    private var retryAfter: Date?

    /// - Parameter queueFileURL: where waiting events are kept between launches; nil keeps them in
    ///   memory only. `standardQueueURL(directory:)` gives the usual location.
    public init(
        configuration: PostHogConfiguration,
        transport: any AnalyticsHTTPTransport = URLSessionAnalyticsTransport(),
        queueFileURL: URL? = nil,
        clock: any GameTimeClock = SystemGameTimeClock(),
        makeUUID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.queueFileURL = queueFileURL
        self.clock = clock
        self.makeUUID = makeUUID
        self.pending = queueFileURL.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([QueuedEvent].self, from: $0) } ?? []
    }

    /// `Application Support/<directory>/posthog-queue.json`.
    public static func standardQueueURL(directory: String) -> URL {
        AnalyticsFiles.url(directory: directory, file: "posthog-queue.json")
    }

    public var pendingCount: Int { lock.withLock { pending.count } }

    public func track(_ event: AnalyticsEvent) {
        let queued = QueuedEvent(uuid: makeUUID(), name: event.name, properties: event.properties)
        let shouldSend = lock.withLock {
            pending.append(queued)
            if pending.count > configuration.maxQueuedEvents {
                pending.removeFirst(pending.count - configuration.maxQueuedEvents)
            }
            persistLocked()
            return pending.count >= configuration.flushAt
        }
        if shouldSend { flush() }
    }

    /// Sends waiting events now, unless a send is already running or a failed send is backing off.
    public func flush() {
        lock.withLock { startSendLocked() }
    }

    /// Waits until no send is running. Tests use this; the app never needs to.
    public func waitUntilIdle() async {
        while let task = lock.withLock({ sending }) {
            await task.value
        }
    }

    private func startSendLocked() {
        guard sending == nil, !pending.isEmpty else { return }
        if let retryAfter, clock.now < retryAfter { return }
        let batch = Array(pending.prefix(configuration.maxBatchSize))
        guard let body = try? Self.body(for: batch, apiKey: configuration.apiKey) else {
            pending.removeFirst(batch.count)
            persistLocked()
            return
        }
        sending = Task { [self] in
            let result = await transport.post(body, to: configuration.batchURL)
            finish(batch, result: result)
        }
    }

    private func finish(_ batch: [QueuedEvent], result: AnalyticsDeliveryResult) {
        lock.withLock {
            sending = nil
            switch result {
            case .delivered, .rejected:
                let sent = Set(batch.map(\.uuid))
                pending.removeAll { sent.contains($0.uuid) }
                failures = 0
                retryAfter = nil
                persistLocked()
                // Keep going while a backlog remains; starting inside the lock means `waitUntilIdle`
                // never sees a gap between batches.
                startSendLocked()
            case .retryLater:
                failures += 1
                // 30 s, doubling, capped at an hour.
                let delay = min(3_600, 30 * pow(2, Double(min(failures - 1, 7))))
                retryAfter = clock.now.addingTimeInterval(delay)
            }
        }
    }

    private func persistLocked() {
        guard let queueFileURL else { return }
        do {
            try FileManager.default.createDirectory(at: queueFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(pending).write(to: queueFileURL, options: .atomic)
        } catch {
            // Losing queued analytics is acceptable; breaking the game is not.
        }
    }

    // MARK: Payload

    static func body(for batch: [QueuedEvent], apiKey: String) throws -> Data {
        let events: [[String: Any]] = batch.map { event in
            var properties: [String: Any] = [:]
            for (key, value) in event.properties where !omittedKeys.contains(key) {
                properties[key] = jsonValue(value)
            }
            properties["distinct_id"] = event.properties["install_id"] ?? "unknown"
            properties["$process_person_profile"] = false
            properties["$geoip_disable"] = true
            properties["$lib"] = "gametime-kit"
            properties["$lib_version"] = GameTimeKit.version
            if let session = event.properties["session_id"] { properties["$session_id"] = session }

            var payload: [String: Any] = ["event": event.name, "uuid": event.uuid, "properties": properties]
            if let ms = event.properties["ts"].flatMap(Int64.init) {
                payload["timestamp"] = timestamp(ms: ms)
            }
            return payload
        }
        return try JSONSerialization.data(withJSONObject: ["api_key": apiKey, "batch": events], options: [.sortedKeys])
    }

    /// Whole numbers are sent as numbers so PostHog can sum and average them; everything else stays
    /// a string. A leading zero (such as a build "007") keeps the value a string.
    static func jsonValue(_ value: String) -> Any {
        guard let number = Int(value), String(number) == value else { return value }
        return number
    }

    static func timestamp(ms: Int64) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }
}
