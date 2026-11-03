import Foundation
import GameTimeCore

/// How a save is turned into bytes and back. Games that already ship a save format keep it by passing
/// their own codec; new saves can use `versioned(_:migrations:)`.
public struct SaveCodec<Value>: Sendable {
    public let encode: @Sendable (Value) throws -> Data
    public let decode: @Sendable (Data) throws -> Value

    public init(encode: @escaping @Sendable (Value) throws -> Data, decode: @escaping @Sendable (Data) throws -> Value) {
        self.encode = encode
        self.decode = decode
    }
}

public enum SaveCodecError: Error, Equatable, Sendable {
    /// The save was written by a newer build, which this build cannot read.
    case newerVersion(Int)
    /// The save's version is older than the current one and no migration handles it.
    case noMigration(from: Int)
}

extension SaveCodec where Value: Codable {
    /// Plain JSON with sorted keys: the format `JSONEncoder` already gives a `Codable` save.
    public static var json: SaveCodec {
        SaveCodec(
            encode: { try JSONEncoder.sortedKeys.encode($0) },
            decode: { try JSONDecoder().decode(Value.self, from: $0) }
        )
    }

    /// JSON wrapped as `{"schemaVersion": n, "value": …}`. A save from an older version is read by the
    /// migration registered for that version, which receives the whole stored JSON and returns the
    /// current value. A save from a newer version fails with `SaveCodecError.newerVersion`.
    public static func versioned(
        _ currentVersion: Int,
        migrations: [Int: @Sendable (Data) throws -> Value] = [:]
    ) -> SaveCodec {
        SaveCodec(
            encode: { value in
                try JSONEncoder.sortedKeys.encode(VersionedEnvelope(schemaVersion: currentVersion, value: value))
            },
            decode: { data in
                let version = try JSONDecoder().decode(VersionProbe.self, from: data).schemaVersion
                if version == currentVersion {
                    return try JSONDecoder().decode(VersionedEnvelope<Value>.self, from: data).value
                }
                if version > currentVersion { throw SaveCodecError.newerVersion(version) }
                guard let migrate = migrations[version] else { throw SaveCodecError.noMigration(from: version) }
                return try migrate(data)
            }
        )
    }
}

private struct VersionProbe: Decodable {
    let schemaVersion: Int
}

private struct VersionedEnvelope<Value: Codable>: Codable {
    let schemaVersion: Int
    let value: Value
}

/// What `SaveStore.load()` found.
public enum SaveLoad<Value> {
    /// Nothing was saved yet; the value is the store's default.
    case fresh(Value)
    case loaded(Value)
    /// A save existed but could not be read. It was kept as a backup and the default was returned.
    case recovered(Value, SaveRecovery)

    public var value: Value {
        switch self {
        case let .fresh(value), let .loaded(value), let .recovered(value, _): value
        }
    }
}

/// An unreadable save that was set aside instead of being deleted.
public struct SaveRecovery: Codable, Equatable, Sendable {
    /// The `UserDefaults` key the unreadable bytes were copied to.
    public let backupKey: String
    /// Why the save could not be read, for diagnostics and support.
    public let reason: String
    public let date: Date
}

/// Loads and saves one value in `UserDefaults`, and never loses a player's save to a read failure.
///
/// When the stored bytes cannot be decoded (corruption, a save written by a newer build, or a code
/// change that the save does not satisfy), they are copied to a backup key before anything else
/// happens, and `load()` returns the default as `.recovered`. The game decides what to tell the player
/// and can report the recovery. The newest `maxBackups` backups are kept; older ones are removed.
public final class SaveStore<Value>: @unchecked Sendable {
    public static var maxBackups: Int { 3 }

    public let key: String
    private let codec: SaveCodec<Value>
    private let defaults: UserDefaults
    private let clock: any GameTimeClock
    private let makeDefault: @Sendable () -> Value
    private let lock = NSLock()

    /// - Parameters:
    ///   - key: where the save lives. Keep the key a shipped game already uses, so its saves load.
    ///   - makeDefault: the value for a new player, or after an unreadable save.
    public init(
        key: String,
        codec: SaveCodec<Value>,
        defaults: UserDefaults = .standard,
        clock: any GameTimeClock = SystemGameTimeClock(),
        makeDefault: @escaping @Sendable () -> Value
    ) {
        self.key = key
        self.codec = codec
        self.defaults = defaults
        self.clock = clock
        self.makeDefault = makeDefault
    }

    public func load() -> SaveLoad<Value> {
        lock.withLock {
            guard let data = defaults.data(forKey: key) else { return .fresh(makeDefault()) }
            do {
                return .loaded(try codec.decode(data))
            } catch {
                let recovery = backUpLocked(data, reason: String(describing: error))
                return .recovered(makeDefault(), recovery)
            }
        }
    }

    /// Returns false, leaving the stored save untouched, if the value cannot be encoded.
    @discardableResult
    public func save(_ value: Value) -> Bool {
        lock.withLock {
            guard let data = try? codec.encode(value) else { return false }
            defaults.set(data, forKey: key)
            return true
        }
    }

    /// Removes the save, for a player's "reset progress". Backups of unreadable saves are kept.
    public func reset() {
        lock.withLock { defaults.removeObject(forKey: key) }
    }

    /// Backups of unreadable saves, newest first.
    public func backups() -> [SaveRecovery] {
        lock.withLock { backupRecordsLocked().map(\.recovery) }
    }

    /// The bytes of a backup, for a support export or a later build that can read them.
    public func backupData(for recovery: SaveRecovery) -> Data? {
        lock.withLock {
            defaults.data(forKey: recovery.backupKey)
                .flatMap { try? JSONDecoder().decode(BackupRecord.self, from: $0) }?.data
        }
    }

    // MARK: Backups

    private struct BackupRecord: Codable {
        let recovery: SaveRecovery
        let data: Data
    }

    private var backupPrefix: String { "\(key).unreadable." }

    private func backUpLocked(_ data: Data, reason: String) -> SaveRecovery {
        let date = clock.now
        var backupKey = backupPrefix + String(Int64(date.timeIntervalSince1970 * 1000))
        var suffix = 1
        while defaults.object(forKey: backupKey) != nil {
            backupKey = backupPrefix + String(Int64(date.timeIntervalSince1970 * 1000)) + "-\(suffix)"
            suffix += 1
        }
        let recovery = SaveRecovery(backupKey: backupKey, reason: reason, date: date)
        if let record = try? JSONEncoder().encode(BackupRecord(recovery: recovery, data: data)) {
            defaults.set(record, forKey: backupKey)
        }
        for stale in backupRecordsLocked().dropFirst(Self.maxBackups) {
            defaults.removeObject(forKey: stale.recovery.backupKey)
        }
        return recovery
    }

    private func backupRecordsLocked() -> [BackupRecord] {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(backupPrefix) }
            .compactMap { defaults.data(forKey: $0).flatMap { try? JSONDecoder().decode(BackupRecord.self, from: $0) } }
            .sorted { ($0.recovery.date, $0.recovery.backupKey) > ($1.recovery.date, $1.recovery.backupKey) }
    }
}

extension JSONEncoder {
    static let sortedKeys: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}
