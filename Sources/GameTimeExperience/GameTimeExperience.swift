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

/// One semantic event fans out to independently configurable sensory channels.
/// Games retain their sound palette; failures in device adapters must be non-fatal.
public struct GameFeedbackController: Sendable {
    private let audio: any AudioControlling
    private let haptics: any HapticsControlling

    public init(audio: any AudioControlling, haptics: any HapticsControlling) {
        self.audio = audio
        self.haptics = haptics
    }

    public func play(_ event: GameFeedbackEvent, soundEnabled: Bool, hapticsEnabled: Bool) {
        if soundEnabled { audio.play(event) }
        if hapticsEnabled { haptics.play(event) }
    }
}
