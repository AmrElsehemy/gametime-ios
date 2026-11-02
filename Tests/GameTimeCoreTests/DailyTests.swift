import Foundation
import Testing
@testable import GameTimeCore

// MARK: - The games' current implementations, copied verbatim, to prove the shared one matches them.

/// Exactly One's and Flag Trek's `dayKey(for:)` (identical): UTC `yyyy-MM-dd`.
private func legacyUTCDayKey(_ date: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
}

/// Top Off's `DailyPuzzle.dayNumber(for:calendar:)`.
private func legacyTopOffDayNumber(_ date: Date, calendar: Calendar) -> Int {
    var components = DateComponents()
    components.year = 2024
    components.month = 1
    components.day = 1
    let reference = calendar.date(from: components) ?? Date(timeIntervalSince1970: 1_704_067_200)
    let start = calendar.startOfDay(for: reference)
    let today = calendar.startOfDay(for: date)
    return calendar.dateComponents([.day], from: start, to: today).day ?? 0
}

/// Top Off's `TopOffProgress.dailyStreak(today:)` over its `dailyBest` keys.
private func legacyTopOffStreak(_ days: Set<Int>, today: Int) -> Int {
    var day = days.contains(today) ? today : today - 1
    var streak = 0
    while days.contains(day) {
        streak += 1
        day -= 1
    }
    return streak
}

/// Exactly One's `ExactlyOneStreakPolicy.applyingCompletion` over (current, longest, last day).
private func legacyExactlyOneStreak(_ state: (Int, Int, Int?), completing day: Int) -> (Int, Int, Int?) {
    let (current, longest, last) = state
    guard let previous = last else { return (1, max(1, longest), day) }
    let gap = day - previous
    if gap <= 0 { return state }
    let next = switch gap {
    case 1: max(1, current) + 1
    case 2: max(1, current)
    default: 1
    }
    return (next, max(longest, next), day)
}

/// Flag Trek's `AdventureProgress.recordDaily` streak rule: +1 for consecutive days, otherwise 1.
private func legacyFlagTrekStreak(_ state: (Int, Int?), completing day: Int) -> (Int, Int?) {
    let (streak, last) = state
    guard last != day else { return state }
    return ((last != nil && last == day - 1) ? streak + 1 : 1, day)
}

private struct LCG {
    var state: UInt64
    mutating func next(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}

private func calendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

// MARK: - Day boundary parity

@Test func utcDaysMatchExactlyOneAndFlagTrek() {
    var rng = LCG(state: 1)
    // 2019 to 2035, including both sides of every UTC midnight that the random walk lands near.
    for _ in 0..<20_000 {
        let date = Date(timeIntervalSince1970: 1_546_300_800 + Double(rng.next(536_457_600)))
        #expect(DailyCalendar.utc.day(for: date).key == legacyUTCDayKey(date))
    }
    let midnight = Date(timeIntervalSince1970: 1_799_971_200) // 2027-01-15T00:00:00Z
    #expect(DailyCalendar.utc.day(for: midnight.addingTimeInterval(-0.001)).key == "2027-01-14")
    #expect(DailyCalendar.utc.day(for: midnight).key == "2027-01-15")
}

@Test(arguments: ["Europe/London", "America/New_York", "Asia/Tokyo", "Australia/Lord_Howe", "Pacific/Kiritimati", "Africa/Cairo"])
func localDaysMatchTopOff(zone: String) {
    let legacy = calendar(zone)
    let shared = DailyCalendar.local(TimeZone(identifier: zone)!)
    var rng = LCG(state: UInt64(zone.utf8.count))
    for _ in 0..<5_000 {
        let date = Date(timeIntervalSince1970: 1_640_995_200 + Double(rng.next(378_691_200)))
        #expect(shared.day(for: date).index == legacyTopOffDayNumber(date, calendar: legacy))
    }
}

@Test func localDayFollowsTheZonesMidnight() {
    let instant = Date(timeIntervalSince1970: 1_799_971_200 - 3_600) // 2027-01-14T23:00:00Z
    #expect(DailyCalendar.utc.day(for: instant).key == "2027-01-14")
    #expect(DailyCalendar.local(TimeZone(identifier: "Africa/Cairo")!).day(for: instant).key == "2027-01-15")
    #expect(DailyCalendar.local(TimeZone(identifier: "America/New_York")!).day(for: instant).key == "2027-01-14")
}

// MARK: - DailyDay

@Test func dayKeysAndIndexesConvertBothWays() {
    #expect(DailyDay(key: "2024-01-01")?.index == 0)
    #expect(DailyDay(index: 0).weekday == 0, "Day 0 is a Monday")
    #expect(DailyDay(key: "2024-02-29")?.index == 59)
    #expect(DailyDay(key: "2023-12-31")?.index == -1)
    for index in -800...4_000 {
        let day = DailyDay(index: index)
        #expect(DailyDay(key: day.key) == day)
    }
}

@Test func malformedKeysAreRejected() {
    for key in ["", "2024-1-01", "2024-02-30", "2023-02-29", "2024-13-01", "2024/01/01", "20240101", "2024-01-01T00:00"] {
        #expect(DailyDay(key: key) == nil, "\(key)")
    }
}

@Test func daysSaveAsTheirKey() throws {
    let day = try #require(DailyDay(key: "2026-10-31"))
    let data = try JSONEncoder().encode(day)
    #expect(String(decoding: data, as: UTF8.self) == "\"2026-10-31\"")
    #expect(try JSONDecoder().decode(DailyDay.self, from: data) == day)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(DailyDay.self, from: Data("\"nope\"".utf8)) }
}

@Test func daysOrderAndSubtract() {
    let day = DailyDay(index: 10)
    #expect(day < day.adding(days: 1))
    #expect(day.distance(to: day.adding(days: 3)) == 3)
    #expect(day.adding(days: 3).distance(to: day) == -3)
}

// MARK: - Streak parity

@Test func forgivingStreakMatchesExactlyOne() {
    var rng = LCG(state: 7)
    for _ in 0..<300 {
        var legacy: (Int, Int, Int?) = (0, 0, nil)
        var shared = DailyStreak()
        var day = 100
        for _ in 0..<60 {
            day += rng.next(5) - 1 // repeats, earlier days, consecutive days and gaps of up to three
            legacy = legacyExactlyOneStreak(legacy, completing: day)
            shared.recordCompletion(on: DailyDay(index: day), policy: .forgiveOneMissedDay)
            #expect(shared.current == legacy.0)
            #expect(shared.longest == legacy.1)
            #expect(shared.lastCompletedDay?.index == legacy.2)
        }
    }
}

@Test func resettingStreakMatchesFlagTrek() {
    var rng = LCG(state: 11)
    for _ in 0..<300 {
        var legacy: (Int, Int?) = (0, nil)
        var shared = DailyStreak()
        var day = 100
        for _ in 0..<60 {
            day += rng.next(4) // Flag Trek's days only move forward: repeats, consecutive days and gaps
            legacy = legacyFlagTrekStreak(legacy, completing: day)
            shared.recordCompletion(on: DailyDay(index: day), policy: .reset)
            #expect(shared.current == legacy.0)
            #expect(shared.lastCompletedDay?.index == legacy.1)
        }
    }
}

@Test func runLengthMatchesTopOff() {
    var rng = LCG(state: 13)
    for _ in 0..<500 {
        let days = Set((0..<40).filter { _ in rng.next(3) > 0 }.map { $0 + 200 })
        let today = 200 + rng.next(45)
        #expect(
            DailyStreak.length(of: Set(days.map(DailyDay.init(index:))), asOf: DailyDay(index: today))
                == legacyTopOffStreak(days, today: today)
        )
    }
}

// MARK: - Streak behaviour

@Test func repeatsAndEarlierDaysNeverCount() {
    var streak = DailyStreak()
    let first = streak.recordCompletion(on: DailyDay(index: 5), policy: .reset)
    let repeated = streak.recordCompletion(on: DailyDay(index: 5), policy: .reset)
    let earlier = streak.recordCompletion(on: DailyDay(index: 4), policy: .reset)
    #expect(first)
    #expect(!repeated)
    #expect(!earlier)
    #expect(streak.current == 1)
}

@Test func displayedStreakLapsesOnceItCanNoLongerBeContinued() {
    let start = DailyDay(index: 50)
    var streak = DailyStreak()
    for offset in 0..<4 { streak.recordCompletion(on: start.adding(days: offset), policy: .reset) }
    let last = start.adding(days: 3)

    #expect(streak.displayed(today: last, policy: .reset) == 4, "Solved today")
    #expect(streak.displayed(today: last.adding(days: 1), policy: .reset) == 4, "Today is still open")
    #expect(streak.displayed(today: last.adding(days: 2), policy: .reset) == 0, "Yesterday was missed")
    #expect(streak.displayed(today: last.adding(days: 2), policy: .forgiveOneMissedDay) == 4, "One miss is forgiven")
    #expect(streak.displayed(today: last.adding(days: 3), policy: .forgiveOneMissedDay) == 0, "Two misses are not")
    #expect(streak.displayed(today: last.adding(days: -10), policy: .reset) == 4, "A clock set back keeps the streak")
    #expect(DailyStreak().displayed(today: last, policy: .reset) == 0)
    #expect(streak.longest == 4)
}

@Test func savedStreaksRestore() throws {
    let saved = DailyStreak(current: 3, longest: 9, lastCompletedDay: DailyDay(key: "2026-10-30"))
    let restored = try JSONDecoder().decode(DailyStreak.self, from: JSONEncoder().encode(saved))
    #expect(restored == saved)
    #expect(DailyStreak(current: 5, longest: 2).longest == 5, "Longest is never below current")
}

// MARK: - StableHash

@Test func stableHashIsStandardFNV1a() {
    #expect(StableHash.fnv1a("") == 0xcbf2_9ce4_8422_2325)
    #expect(StableHash.fnv1a("a") == 0xaf63_dc4c_8601_ec8c)
    #expect(StableHash.fnv1a("foobar") == 0x8594_4171_f739_67e8)
}
