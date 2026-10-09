import Foundation

/// A haptic cue described as data, so a game defines its feel without touching Core Haptics.
public struct HapticPattern: Sendable, Equatable {
    public struct Element: Sendable, Equatable {
        public enum Kind: Sendable, Equatable {
            /// A single sharp tap.
            case tap
            /// A sustained rumble lasting `duration`.
            case rumble(duration: TimeInterval)
        }

        public var kind: Kind
        public var time: TimeInterval
        public var intensity: Float
        public var sharpness: Float

        public init(_ kind: Kind, at time: TimeInterval = 0, intensity: Float, sharpness: Float) {
            self.kind = kind
            self.time = time
            self.intensity = intensity
            self.sharpness = sharpness
        }

        public static func tap(at time: TimeInterval = 0, intensity: Float, sharpness: Float) -> Element {
            Element(.tap, at: time, intensity: intensity, sharpness: sharpness)
        }

        public static func rumble(
            at time: TimeInterval = 0,
            duration: TimeInterval,
            intensity: Float,
            sharpness: Float
        ) -> Element {
            Element(.rumble(duration: duration), at: time, intensity: intensity, sharpness: sharpness)
        }
    }

    /// A point on a curve that scales every rumble's intensity over the pattern's lifetime.
    public struct CurvePoint: Sendable, Equatable {
        public var time: TimeInterval
        public var value: Float

        public init(time: TimeInterval, value: Float) {
            self.time = time
            self.value = value
        }
    }

    public var elements: [Element]
    public var intensityCurve: [CurvePoint]
    /// Where the curve starts relative to the pattern start.
    public var curveStart: TimeInterval

    public init(_ elements: [Element], intensityCurve: [CurvePoint] = [], curveStart: TimeInterval = 0) {
        self.elements = elements
        self.intensityCurve = intensityCurve
        self.curveStart = curveStart
    }
}
