import Foundation
import GameTimeCore

public enum GameFeedbackEvent: String, Codable, CaseIterable, Sendable {
    case placement
    case invalidMove
    case conflict
    case hint
    case undo
    case solve
    case milestone
}

public protocol HapticsControlling: Sendable {
    func play(_ event: GameFeedbackEvent)
    func setEnabled(_ enabled: Bool)
}

public protocol AudioControlling: Sendable {
    func play(_ event: GameFeedbackEvent)
    func setEnabled(_ enabled: Bool)
}

public struct NoOpHapticsController: HapticsControlling {
    public init() {}
    public func play(_ event: GameFeedbackEvent) {}
    public func setEnabled(_ enabled: Bool) {}
}

public struct NoOpAudioController: AudioControlling {
    public init() {}
    public func play(_ event: GameFeedbackEvent) {}
    public func setEnabled(_ enabled: Bool) {}
}
