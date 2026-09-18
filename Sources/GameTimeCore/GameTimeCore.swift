import Foundation

public enum GameTimeKit {
    public static let version = "0.1.0-dev"
}

public protocol GameTimeClock: Sendable {
    var now: Date { get }
}

public struct SystemGameTimeClock: GameTimeClock {
    public init() {}
    public var now: Date { Date() }
}

public protocol GameTimeRandomSource: Sendable {
    mutating func nextUInt64() -> UInt64
}

public struct SeededRandomSource: GameTimeRandomSource {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

public struct GameBuildInfo: Codable, Equatable, Sendable {
    public let appVersion: String
    public let buildNumber: String

    public init(appVersion: String, buildNumber: String) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
    }
}
