import Foundation

/// Decides which calendar day a moment belongs to, for daily puzzles and streaks.
///
/// UTC gives every player the same day at the same instant (shared leaderboards, and travelling never
/// breaks a streak). A local time zone makes the day turn over at the player's midnight. Pick one per
/// game and never change it, because saved days and streaks only mean something under the same rule.
public struct DailyCalendar: Sendable, Equatable {
    public let timeZone: TimeZone

    public init(timeZone: TimeZone) {
        self.timeZone = timeZone
    }

    /// Days turn over at 00:00 UTC.
    public static let utc = DailyCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)

    /// Days turn over at midnight in `timeZone`, by default the device's current one.
    public static func local(_ timeZone: TimeZone = .current) -> DailyCalendar {
        DailyCalendar(timeZone: timeZone)
    }

    public func day(for date: Date) -> DailyDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return DailyDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}

/// One calendar day, independent of time zone once it has been worked out by a `DailyCalendar`.
///
/// It converts losslessly between the two forms games already save: a `yyyy-MM-dd` key, and a day
/// number counted from Monday 1 January 2024 (day 0). Days are ordered and can be subtracted.
public struct DailyDay: Hashable, Comparable, Sendable {
    /// Whole days since 1 January 2024; negative before it. Day 0 is a Monday.
    public let index: Int

    public init(index: Int) {
        self.index = index
    }

    public init(year: Int, month: Int, day: Int) {
        index = Self.daysFromCivil(year: year, month: month, day: day) - Self.epochOffset
    }

    /// Parses `yyyy-MM-dd`; nil for anything else, including impossible dates.
    public init?(key: String) {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        self.init(year: year, month: month, day: day)
        guard self.key == key else { return nil }
    }

    /// `yyyy-MM-dd`.
    public var key: String {
        let (year, month, day) = Self.civil(fromDays: index + Self.epochOffset)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// 0 for Monday through 6 for Sunday.
    public var weekday: Int { ((index % 7) + 7) % 7 }

    public func adding(days: Int) -> DailyDay { DailyDay(index: index + days) }

    /// Days from `self` to `other`: 1 when `other` is the next day, negative when it is earlier.
    public func distance(to other: DailyDay) -> Int { other.index - index }

    public static func < (lhs: DailyDay, rhs: DailyDay) -> Bool { lhs.index < rhs.index }

    // Days since 1970-01-01 for a proleptic Gregorian date (H. Hinnant's algorithm), so day arithmetic
    // never touches time zones or daylight saving.
    private static let epochOffset = daysFromCivil(year: 2024, month: 1, day: 1)

    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private static func civil(fromDays days: Int) -> (Int, Int, Int) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }
}

/// Saved as its `yyyy-MM-dd` key, which reads well in a save file and survives any change of epoch.
extension DailyDay: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let key = try container.decode(String.self)
        guard let day = DailyDay(key: key) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a yyyy-MM-dd day: \(key)")
        }
        self = day
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(key)
    }
}

/// Consecutive days on which the player completed the daily puzzle.
public struct DailyStreak: Codable, Equatable, Sendable {
    /// What a day without a completion does to the streak.
    public enum MissPolicy: Sendable, Equatable {
        /// Any missed day ends the streak.
        case reset
        /// A single missed day is forgiven: the streak is kept (not increased) when the player comes back
        /// the day after. Two missed days in a row end it.
        case forgiveOneMissedDay

        /// The largest gap between completions that keeps the streak alive.
        var longestLivingGap: Int {
            switch self {
            case .reset: 1
            case .forgiveOneMissedDay: 2
            }
        }
    }

    /// The streak as of `lastCompletedDay`. Use `displayed(today:policy:)` for what to show now.
    public private(set) var current: Int
    public private(set) var longest: Int
    public private(set) var lastCompletedDay: DailyDay?

    public init(current: Int = 0, longest: Int = 0, lastCompletedDay: DailyDay? = nil) {
        self.current = max(0, current)
        self.longest = max(self.current, longest)
        self.lastCompletedDay = lastCompletedDay
    }

    /// Records a completion. Returns false, changing nothing, for a day already counted or earlier than
    /// the last one, so replays and clock changes can never inflate a streak.
    @discardableResult
    public mutating func recordCompletion(on day: DailyDay, policy: MissPolicy) -> Bool {
        guard let last = lastCompletedDay else {
            current = 1
            longest = max(longest, 1)
            lastCompletedDay = day
            return true
        }
        let gap = last.distance(to: day)
        guard gap > 0 else { return false }
        switch gap {
        case 1:
            current = max(1, current) + 1
        case 2 where policy == .forgiveOneMissedDay:
            current = max(1, current)
        default:
            current = 1
        }
        longest = max(longest, current)
        lastCompletedDay = day
        return true
    }

    /// The streak to show on `today`: the saved count while it can still be continued, 0 once enough
    /// days have been missed that the next completion would start again from 1.
    public func displayed(today: DailyDay, policy: MissPolicy) -> Int {
        guard let last = lastCompletedDay else { return 0 }
        // A clock set backwards is not the player's fault; keep showing what they earned.
        return last.distance(to: today) <= policy.longestLivingGap ? current : 0
    }

    /// The run of consecutive days in `days` that ends today, or yesterday while today is still open.
    /// For games that keep a set of completed days instead of a `DailyStreak`.
    public static func length(of days: Set<DailyDay>, asOf today: DailyDay) -> Int {
        var day = days.contains(today) ? today : today.adding(days: -1)
        var length = 0
        while days.contains(day) {
            length += 1
            day = day.adding(days: -1)
        }
        return length
    }
}

public enum StableHash {
    /// 64-bit FNV-1a. `Hashable.hashValue` is randomised per launch, so it cannot seed anything that has
    /// to come out the same on every device, such as a daily puzzle.
    public static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
