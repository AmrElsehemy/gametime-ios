import Foundation

/// The sound and haptics switches every game has. Both are on for a new player.
public struct FeedbackSettings: Codable, Equatable, Sendable {
    public var soundEnabled: Bool
    public var hapticsEnabled: Bool

    public init(soundEnabled: Bool = true, hapticsEnabled: Bool = true) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
    }
}

/// Keeps `FeedbackSettings` in two `UserDefaults` booleans. Games pass the keys they already ship, so a
/// player's existing choices carry over, and a key that was never written reads as on.
public final class FeedbackSettingsStore: @unchecked Sendable {
    public let soundKey: String
    public let hapticsKey: String
    private let defaults: UserDefaults

    public init(soundKey: String, hapticsKey: String, defaults: UserDefaults = .standard) {
        self.soundKey = soundKey
        self.hapticsKey = hapticsKey
        self.defaults = defaults
    }

    public var current: FeedbackSettings {
        FeedbackSettings(soundEnabled: bool(soundKey), hapticsEnabled: bool(hapticsKey))
    }

    public func setSoundEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: soundKey)
    }

    public func setHapticsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: hapticsKey)
    }

    public func save(_ settings: FeedbackSettings) {
        setSoundEnabled(settings.soundEnabled)
        setHapticsEnabled(settings.hapticsEnabled)
    }

    private func bool(_ key: String) -> Bool {
        defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }
}
