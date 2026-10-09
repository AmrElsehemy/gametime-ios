import Foundation

/// A short sound rendered from a formula, so a game ships no audio files and its palette stays
/// tunable in code. Mono, 44.1 kHz, always within ±0.95 so no cue can clip.
public struct SynthSound: Sendable, Equatable {
    public static let sampleRate = 44_100.0

    public let samples: [Float]

    public init(samples: [Float]) {
        self.samples = samples
    }

    public var duration: TimeInterval {
        Double(samples.count) / Self.sampleRate
    }

    /// Renders `duration` seconds by calling `sample` with the time in seconds. `sample` runs
    /// once, immediately, so it may freely keep mutable state such as a noise generator.
    public static func render(duration: Double, _ sample: (Double) -> Double) -> SynthSound {
        let count = max(0, Int(duration * sampleRate))
        var samples = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let value = sample(Double(index) / sampleRate)
            samples[index] = Float(max(-0.95, min(0.95, value.isFinite ? value : 0)))
        }
        return SynthSound(samples: samples)
    }

    /// A struck-bell partial: a sine with an inharmonic overtone, decaying exponentially. Returns 0
    /// before `t` reaches zero, so notes can be placed in time by passing `t - start`.
    public static func bell(_ frequency: Double, at t: Double, decay: Double) -> Double {
        guard t >= 0 else { return 0 }
        return sin(2 * .pi * frequency * t) * exp(-t * decay)
            + 0.3 * sin(2 * .pi * frequency * 2.76 * t) * exp(-t * decay * 1.8)
    }
}
