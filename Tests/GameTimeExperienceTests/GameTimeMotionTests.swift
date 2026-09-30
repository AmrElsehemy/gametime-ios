import XCTest
@testable import GameTimeExperience

final class GameTimeMotionTests: XCTestCase {
    func testStaggerOffsetsAreDeterministic() {
        let actual = GameTimeMotion.staggerOffsets(count: 4, step: 0.025)
        for (value, expected) in zip(actual, [0.0, 0.025, 0.05, 0.075]) {
            XCTAssertEqual(value, expected, accuracy: 1e-12)
        }
        XCTAssertEqual(actual, GameTimeMotion.staggerOffsets(count: 4, step: 0.025))
    }

    func testStaggerOffsetsClampNegativeStep() {
        XCTAssertEqual(
            GameTimeMotion.staggerOffsets(count: 3, step: -1),
            [0, 0, 0]
        )
    }

    func testStaggerOffsetsHandleEmptyInput() {
        XCTAssertEqual(GameTimeMotion.staggerOffsets(count: 0, step: 0.1), [])
    }
}

extension GameTimeMotionTests {
    func testNonFiniteStaggerDoesNotCreateInvalidActions() {
        XCTAssertEqual(GameTimeMotion.staggerOffsets(count: 2, step: .infinity), [0, 0])
        XCTAssertEqual(GameTimeMotion.staggerOffsets(count: 2, step: .nan), [0, 0])
    }

    func testReducedMotionHasBoundedFeedbackDurations() {
        XCTAssertEqual(GameTimeMotion.placementPop(reduceMotion: true).duration, 0.12, accuracy: 1e-6)
        XCTAssertEqual(GameTimeMotion.invalidShake(reduceMotion: true).duration, 0.22, accuracy: 1e-6)
        XCTAssertEqual(GameTimeMotion.levelEnter(reduceMotion: true).duration, 0.18, accuracy: 1e-6)
    }
}
