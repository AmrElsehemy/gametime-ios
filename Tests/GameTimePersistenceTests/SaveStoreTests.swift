import Foundation
import GameTimeCore
import Testing
@testable import GameTimePersistence

private struct Progress: Codable, Equatable, Sendable {
    var stars: [String: Int] = [:]
    var streak = 0
}

/// The same save after a code change that added a required field: old saves no longer decode.
private struct ProgressV2: Codable, Equatable, Sendable {
    var stars: [String: Int]
    var streak: Int
    var coins: Int
}

private final class MutableClock: GameTimeClock, @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_800_000_000)
    var now: Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date = date.addingTimeInterval(seconds) } }
}

private final class Fixture {
    let suite = "gametime.persistence.tests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let clock = MutableClock()

    init() { defaults = UserDefaults(suiteName: suite)! }
    deinit { defaults.removePersistentDomain(forName: suite) }

    func store<Value: Codable & Sendable>(
        _ codec: SaveCodec<Value>, key: String = "game.progress.v1", default makeDefault: @escaping @Sendable () -> Value
    ) -> SaveStore<Value> {
        SaveStore(key: key, codec: codec, defaults: defaults, clock: clock, makeDefault: makeDefault)
    }
}

@Test func aNewPlayerGetsTheDefault() {
    let f = Fixture()
    let store = f.store(.json) { Progress(streak: 0) }
    guard case .fresh(let value) = store.load() else { Issue.record("Expected fresh"); return }
    #expect(value == Progress())
}

@Test func plainJSONSavesFromShippedBuildsLoadAndStayInTheSameFormat() throws {
    let f = Fixture()
    // Written the way Top Off and Flag Trek save today: JSONEncoder straight into UserDefaults.
    let shipped = Progress(stars: ["europe-1": 3], streak: 4)
    f.defaults.set(try JSONEncoder().encode(shipped), forKey: "game.progress.v1")

    let store = f.store(.json) { Progress() }
    guard case .loaded(let value) = store.load() else { Issue.record("Expected loaded"); return }
    #expect(value == shipped)

    store.save(Progress(stars: ["europe-1": 3], streak: 5))
    let reread = try JSONDecoder().decode(Progress.self, from: try #require(f.defaults.data(forKey: "game.progress.v1")))
    #expect(reread.streak == 5, "A previous build's plain decoder can still read what the store writes")
}

@Test func anUnreadableSaveIsBackedUpNeverDeleted() throws {
    let f = Fixture()
    let original = try JSONEncoder().encode(Progress(stars: ["asia-2": 2], streak: 9))
    f.defaults.set(original, forKey: "game.progress.v1")

    // A later build added a required field, so the shipped save no longer decodes.
    let store = f.store(.json) { ProgressV2(stars: [:], streak: 0, coins: 0) }
    guard case .recovered(let value, let recovery) = store.load() else { Issue.record("Expected recovered"); return }
    #expect(value == ProgressV2(stars: [:], streak: 0, coins: 0))
    #expect(recovery.date == f.clock.now)
    #expect(recovery.reason.contains("coins"), "The reason names what failed: \(recovery.reason)")

    #expect(store.backupData(for: recovery) == original, "The player's bytes are kept exactly")
    #expect(f.defaults.data(forKey: "game.progress.v1") == original, "Loading alone changes nothing")

    store.save(ProgressV2(stars: [:], streak: 0, coins: 10))
    #expect(store.backups() == [recovery], "Saving fresh progress keeps the backup")
    #expect(store.backupData(for: recovery) == original)
}

@Test func onlyTheNewestBackupsAreKept() throws {
    let f = Fixture()
    let store = f.store(.json) { Progress() }
    var made: [SaveRecovery] = []
    for index in 0..<5 {
        f.defaults.set(Data("broken \(index)".utf8), forKey: "game.progress.v1")
        guard case .recovered(_, let recovery) = store.load() else { Issue.record("Expected recovered"); return }
        made.append(recovery)
        f.clock.advance(60)
    }
    #expect(store.backups() == Array(made.suffix(SaveStore<Progress>.maxBackups).reversed()))
    #expect(store.backupData(for: made[4]) == Data("broken 4".utf8))
    #expect(store.backupData(for: made[0]) == nil)
}

@Test func backupsTakenAtTheSameInstantDoNotOverwriteEachOther() {
    let f = Fixture()
    let store = f.store(.json) { Progress() }
    f.defaults.set(Data("first".utf8), forKey: "game.progress.v1")
    _ = store.load()
    f.defaults.set(Data("second".utf8), forKey: "game.progress.v1")
    _ = store.load()
    let kept = store.backups()
    #expect(kept.count == 2)
    #expect(Set(kept.compactMap { store.backupData(for: $0) }) == [Data("first".utf8), Data("second".utf8)])
}

@Test func resetRemovesTheSaveButKeepsBackups() {
    let f = Fixture()
    let store = f.store(.json) { Progress() }
    f.defaults.set(Data("broken".utf8), forKey: "game.progress.v1")
    _ = store.load()
    store.save(Progress(streak: 2))
    store.reset()
    guard case .fresh = store.load() else { Issue.record("Expected fresh after reset"); return }
    #expect(store.backups().count == 1)
}

@Test func storesUnderDifferentKeysKeepSeparateBackups() {
    let f = Fixture()
    let progress = f.store(.json, key: "game.progress.v1") { Progress() }
    let onboarding = f.store(.json, key: "game.progress.v1.onboarding") { Progress() }
    f.defaults.set(Data("broken".utf8), forKey: "game.progress.v1.onboarding")
    _ = onboarding.load()
    #expect(progress.backups().isEmpty, "A key that only shares a prefix does not see another store's backups")
    #expect(onboarding.backups().count == 1)
}

@Test func aSaveThatCannotBeEncodedLeavesTheStoredOneAlone() throws {
    let f = Fixture()
    struct Unencodable: Error {}
    let codec = SaveCodec<Int>(
        encode: { value in
            if value < 0 { throw Unencodable() }
            return Data(String(value).utf8)
        },
        decode: { Int(String(decoding: $0, as: UTF8.self)) ?? 0 }
    )
    let store = f.store(codec) { 0 }
    #expect(store.save(7))
    #expect(!store.save(-1))
    #expect(store.load().value == 7)
}

// MARK: Versioned codec

@Test func versionedSavesRoundTrip() throws {
    let f = Fixture()
    let store = f.store(.versioned(2)) { Progress() }
    store.save(Progress(stars: ["a": 1], streak: 3))
    let json = try JSONSerialization.jsonObject(with: try #require(f.defaults.data(forKey: "game.progress.v1"))) as? [String: Any]
    #expect(json?["schemaVersion"] as? Int == 2)
    guard case .loaded(let value) = store.load() else { Issue.record("Expected loaded"); return }
    #expect(value == Progress(stars: ["a": 1], streak: 3))
}

@Test func olderVersionsMigrateAndNewerOnesAreBackedUp() throws {
    struct V1: Codable { let stars: [String: Int] }
    struct Envelope<T: Codable>: Codable { let schemaVersion: Int; let value: T }
    let f = Fixture()
    let codec = SaveCodec<Progress>.versioned(2, migrations: [
        1: { data in
            let old = try JSONDecoder().decode(Envelope<V1>.self, from: data).value
            return Progress(stars: old.stars, streak: 0)
        }
    ])
    let store = f.store(codec) { Progress() }

    f.defaults.set(try JSONEncoder().encode(Envelope(schemaVersion: 1, value: V1(stars: ["b": 2]))), forKey: "game.progress.v1")
    guard case .loaded(let migrated) = store.load() else { Issue.record("Expected a migrated load"); return }
    #expect(migrated == Progress(stars: ["b": 2], streak: 0))

    f.defaults.set(try JSONEncoder().encode(Envelope(schemaVersion: 3, value: Progress())), forKey: "game.progress.v1")
    guard case .recovered(_, let recovery) = store.load() else { Issue.record("Expected a newer save to be backed up"); return }
    #expect(recovery.reason.contains("newerVersion(3)"))

    f.defaults.set(try JSONEncoder().encode(Envelope(schemaVersion: 0, value: Progress())), forKey: "game.progress.v1")
    guard case .recovered(_, let missing) = store.load() else { Issue.record("Expected a missing migration to be backed up"); return }
    #expect(missing.reason.contains("noMigration"))
}

// MARK: Feedback settings

@Test func feedbackSettingsDefaultToOnAndKeepExistingChoices() {
    let f = Fixture()
    let store = FeedbackSettingsStore(soundKey: "game.sound", hapticsKey: "game.haptics", defaults: f.defaults)
    #expect(store.current == FeedbackSettings(soundEnabled: true, hapticsEnabled: true))

    // A choice saved by a shipped build under the same key carries over.
    f.defaults.set(false, forKey: "game.haptics")
    #expect(store.current == FeedbackSettings(soundEnabled: true, hapticsEnabled: false))

    store.setSoundEnabled(false)
    store.setHapticsEnabled(true)
    #expect(store.current == FeedbackSettings(soundEnabled: false, hapticsEnabled: true))
    #expect(f.defaults.bool(forKey: "game.sound") == false)

    store.save(FeedbackSettings())
    #expect(store.current == FeedbackSettings())
}
