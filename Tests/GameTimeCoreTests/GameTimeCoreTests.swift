import Foundation
import Testing
@testable import GameTimeCore
import GameTimeTesting

@Test func seededRandomSourceIsDeterministic() {
    var first = SeededRandomSource(seed: 42)
    var second = SeededRandomSource(seed: 42)

    #expect(first.nextUInt64() == second.nextUInt64())
    #expect(first.nextUInt64() == second.nextUInt64())
}

@Test func fixedClockReturnsInjectedTime() {
    let expected = Date(timeIntervalSince1970: 1_700_000_000)
    let clock = FixedGameTimeClock(now: expected)
    #expect(clock.now == expected)
}
