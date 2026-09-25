import XCTest
@testable import GameTimeExperience

final class GameTimeMotionTests: XCTestCase {
    func testStaggerOffsetsAreDeterministic() {
        XCTAssertEqual(
            GameTimeMotion.staggerOffsets(count: 4, step: 0.025),
            [0, 0.025, 0.05, 0.075]
        )
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
