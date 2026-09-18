import Foundation
import GameTimeCore
import GameTimeServices
import GameTimeCommerce

public struct FixedGameTimeClock: GameTimeClock {
    public let now: Date
    public init(now: Date) { self.now = now }
}

public final class RecordingAnalyticsClient: AnalyticsClient, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AnalyticsEvent] = []

    public init() {}

    public var events: [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    public func track(_ event: AnalyticsEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }
}
