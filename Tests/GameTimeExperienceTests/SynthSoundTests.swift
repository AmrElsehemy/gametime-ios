import XCTest
@testable import GameTimeExperience

final class SynthSoundTests: XCTestCase {
    func testRenderProducesTheRequestedDuration() {
        let sound = SynthSound.render(duration: 0.5) { _ in 0.2 }
        XCTAssertEqual(sound.samples.count, 22_050)
        XCTAssertEqual(sound.duration, 0.5, accuracy: 0.001)
    }

    func testRenderClampsSoNoCueCanClip() {
        let loud = SynthSound.render(duration: 0.01) { _ in 5 }
        XCTAssertTrue(loud.samples.allSatisfy { abs($0) <= 0.95 })
        let broken = SynthSound.render(duration: 0.01) { _ in .nan }
        XCTAssertTrue(broken.samples.allSatisfy { $0 == 0 }, "Non-finite samples become silence")
    }

    func testRenderMayKeepMutableStateBetweenSamples() {
        var count = 0
        let sound = SynthSound.render(duration: 0.001) { _ in
            count += 1
            return 0
        }
        XCTAssertEqual(count, sound.samples.count)
    }

    func testRenderIsDeterministic() {
        let make = { SynthSound.render(duration: 0.05) { sin(2 * .pi * 440 * $0) } }
        XCTAssertEqual(make(), make())
    }

    func testBellIsSilentBeforeItsStartAndDecaysAfter() {
        XCTAssertEqual(SynthSound.bell(880, at: -0.1, decay: 5), 0)
        let early = abs(SynthSound.bell(880, at: 0.001, decay: 5))
        let late = abs(SynthSound.bell(880, at: 1.0, decay: 5))
        XCTAssertGreaterThan(early, late)
    }

    func testNegativeDurationRendersNothing() {
        XCTAssertTrue(SynthSound.render(duration: -1) { _ in 1 }.samples.isEmpty)
    }
}

final class HapticPatternTests: XCTestCase {
    func testElementsDescribeTapsAndRumbles() {
        let pattern = HapticPattern(
            [.tap(intensity: 0.5, sharpness: 0.3), .rumble(at: 0.04, duration: 0.5, intensity: 0.4, sharpness: 0.1)],
            intensityCurve: [.init(time: 0, value: 0.5), .init(time: 0.5, value: 0.2)],
            curveStart: 0.04
        )
        XCTAssertEqual(pattern.elements.count, 2)
        XCTAssertEqual(pattern.elements[0].kind, .tap)
        XCTAssertEqual(pattern.elements[1].kind, .rumble(duration: 0.5))
        XCTAssertEqual(pattern.curveStart, 0.04)
        XCTAssertEqual(pattern, pattern)
    }
}
