#if canImport(UIKit) && canImport(CoreHaptics) && canImport(AVFoundation)
import AVFoundation
import CoreHaptics
import Foundation
import UIKit

/// Plays a game's `HapticPattern` for each semantic event through Core Haptics, falling back to
/// UIKit feedback generators on hardware without it. Failures are never fatal.
public final class CoreHapticsController: HapticsControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = true
    private let engine: HapticEngine

    @MainActor
    public init(patterns: [GameFeedbackEvent: HapticPattern]) {
        self.engine = HapticEngine(patterns: patterns)
    }

    public func setEnabled(_ enabled: Bool) {
        lock.withLock { self.enabled = enabled }
    }

    public func play(_ event: GameFeedbackEvent) {
        guard lock.withLock({ enabled }) else { return }
        let engine = engine
        Task { @MainActor in engine.play(event) }
    }
}

@MainActor
private final class HapticEngine {
    private let patterns: [GameFeedbackEvent: HapticPattern]
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?

    init(patterns: [GameFeedbackEvent: HapticPattern]) {
        self.patterns = patterns
    }

    func play(_ event: GameFeedbackEvent) {
        guard
            supportsHaptics,
            let pattern = patterns[event],
            let engine = preparedEngine()
        else {
            playFallback(event)
            return
        }
        do {
            let player = try engine.makePlayer(with: try Self.corePattern(pattern))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            playFallback(event)
        }
    }

    private func preparedEngine() -> CHHapticEngine? {
        if let engine { return engine }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            try engine.start()
            self.engine = engine
            return engine
        } catch {
            return nil
        }
    }

    private static func corePattern(_ pattern: HapticPattern) throws -> CHHapticPattern {
        let events = pattern.elements.map { element -> CHHapticEvent in
            let parameters = [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: element.intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: element.sharpness)
            ]
            switch element.kind {
            case .tap:
                return CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: element.time)
            case .rumble(let duration):
                return CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: parameters,
                    relativeTime: element.time,
                    duration: duration
                )
            }
        }
        let curves: [CHHapticParameterCurve] = pattern.intensityCurve.isEmpty ? [] : [
            CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: pattern.intensityCurve.map {
                    .init(relativeTime: $0.time, value: $0.value)
                },
                relativeTime: pattern.curveStart
            )
        ]
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }

    private func playFallback(_ event: GameFeedbackEvent) {
        switch event {
        case .invalidMove, .conflict:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .solve, .milestone:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .pour:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.85)
        case .undo, .placement, .hint:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
        }
    }
}

/// Plays a game's `SynthSound` for each semantic event. One player node per event, so a new play
/// cuts off the previous one. Uses the ambient audio category: it mixes with the player's music
/// and respects the silent switch.
public final class SynthAudioController: AudioControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = true
    private let engine: SoundEngine

    @MainActor
    public init(sounds: [GameFeedbackEvent: SynthSound], volume: Float = 0.9) {
        self.engine = SoundEngine(sounds: sounds, volume: volume)
    }

    public func setEnabled(_ enabled: Bool) {
        lock.withLock { self.enabled = enabled }
    }

    public func play(_ event: GameFeedbackEvent) {
        guard lock.withLock({ enabled }) else { return }
        let engine = engine
        Task { @MainActor in engine.play(event) }
    }
}

@MainActor
private final class SoundEngine {
    private let sounds: [GameFeedbackEvent: SynthSound]
    private let volume: Float
    private let engine = AVAudioEngine()
    private var players: [GameFeedbackEvent: AVAudioPlayerNode] = [:]
    private var buffers: [GameFeedbackEvent: AVAudioPCMBuffer] = [:]
    private var isReady = false

    private static let format = AVAudioFormat(
        standardFormatWithSampleRate: SynthSound.sampleRate,
        channels: 1
    )!

    init(sounds: [GameFeedbackEvent: SynthSound], volume: Float) {
        self.sounds = sounds
        self.volume = volume
    }

    func play(_ event: GameFeedbackEvent) {
        prepareIfNeeded()
        guard isReady, let player = players[event], let buffer = buffers[event] else { return }
        if !engine.isRunning { try? engine.start() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private func prepareIfNeeded() {
        guard !isReady else { return }

        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        for (event, sound) in sounds {
            guard let buffer = Self.buffer(for: sound) else { continue }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: Self.format)
            players[event] = player
            buffers[event] = buffer
        }
        engine.mainMixerNode.outputVolume = volume
        do {
            try engine.start()
            isReady = true
        } catch {
            isReady = false
        }
    }

    private static func buffer(for sound: SynthSound) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(sound.samples.count)
        guard
            frames > 0,
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
            let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frames
        for (index, sample) in sound.samples.enumerated() {
            channel[index] = sample
        }
        return buffer
    }
}
#endif
