import Foundation
import GameTimeCore
import GameTimeServices
import Testing
@testable import GameTimeAnalytics

private final class FakeTransport: AnalyticsHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [AnalyticsDeliveryResult]
    private var bodies: [(url: URL, body: Data)] = []

    init(results: [AnalyticsDeliveryResult] = []) {
        self.results = results
    }

    func post(_ body: Data, to url: URL) async -> AnalyticsDeliveryResult {
        lock.withLock {
            bodies.append((url, body))
            return results.isEmpty ? .delivered : results.removeFirst()
        }
    }

    var requests: [(url: URL, body: [String: Any])] {
        lock.withLock {
            bodies.map { ($0.url, (try? JSONSerialization.jsonObject(with: $0.body)) as? [String: Any] ?? [:]) }
        }
    }

    var batches: [[[String: Any]]] { requests.map { $0.body["batch"] as? [[String: Any]] ?? [] } }
}

private struct ClockAdapter: GameTimeClock {
    let clock: TestClock
    var now: Date { clock.now }
}

private let key = "phc_test"

private func configuration(flushAt: Int = 3, maxBatchSize: Int = 100, maxQueuedEvents: Int = 1_000) -> PostHogConfiguration {
    PostHogConfiguration(apiKey: key, flushAt: flushAt, maxBatchSize: maxBatchSize, maxQueuedEvents: maxQueuedEvents)!
}

private func event(_ name: String, seq: Int = 1) -> AnalyticsEvent {
    AnalyticsEvent(name: name, properties: [
        "install_id": "install-1", "session_id": "session-1", "ts": "1800000000123",
        "seq": String(seq), "build": "007", "app_version": "1.2", "level_id": "12"
    ])
}

@Test func configurationRejectsMissingOrUnexpandedKeys() {
    #expect(PostHogConfiguration(apiKey: nil) == nil)
    #expect(PostHogConfiguration(apiKey: "  ") == nil)
    #expect(PostHogConfiguration(apiKey: "$(POSTHOG_API_KEY)") == nil, "An unset build setting must not count as a key")
    let config = PostHogConfiguration(infoDictionary: ["PostHogAPIKey": " phc_abc "])
    #expect(config?.apiKey == "phc_abc")
    #expect(config?.host == PostHogConfiguration.euHost)
    #expect(config?.batchURL.absoluteString == "https://eu.i.posthog.com/batch/")
}

@Test func waitsForFlushAtThenSendsOneBatch() async {
    let transport = FakeTransport()
    let client = PostHogAnalyticsClient(configuration: configuration(flushAt: 3), transport: transport)
    client.track(event("a"))
    client.track(event("b"))
    await client.waitUntilIdle()
    #expect(transport.requests.isEmpty)

    client.track(event("c"))
    await client.waitUntilIdle()
    let batches = transport.batches
    #expect(batches.count == 1)
    #expect(batches[0].map { $0["event"] as? String } == ["a", "b", "c"])
    #expect(client.pendingCount == 0)
}

@Test func payloadIsAnonymousAndTyped() async throws {
    let transport = FakeTransport()
    let client = PostHogAnalyticsClient(configuration: configuration(flushAt: 1), transport: transport, makeUUID: { "uuid-1" })
    client.track(event("level_completed"))
    await client.waitUntilIdle()

    let request = try #require(transport.requests.first)
    #expect(request.url.absoluteString == "https://eu.i.posthog.com/batch/")
    #expect(request.body["api_key"] as? String == key)
    let sent = try #require((request.body["batch"] as? [[String: Any]])?.first)
    #expect(sent["uuid"] as? String == "uuid-1")
    #expect(sent["timestamp"] as? String == "2027-01-15T08:00:00.123Z")
    let properties = try #require(sent["properties"] as? [String: Any])
    #expect(properties["distinct_id"] as? String == "install-1")
    #expect(properties["$process_person_profile"] as? Bool == false)
    #expect(properties["$geoip_disable"] as? Bool == true)
    #expect(properties["$session_id"] as? String == "session-1")
    #expect(properties["install_id"] == nil, "Sent once, as distinct_id")
    #expect(properties["ts"] == nil, "Sent once, as the timestamp")
    #expect(properties["level_id"] as? Int == 12, "Whole numbers become numbers")
    #expect(properties["build"] as? String == "007", "A leading zero stays a string")
    #expect(properties["app_version"] as? String == "1.2")
}

@Test func failedSendKeepsEventsAndBacksOff() async {
    let clock = TestClock()
    let transport = FakeTransport(results: [.retryLater])
    let client = PostHogAnalyticsClient(
        configuration: configuration(flushAt: 1), transport: transport, clock: ClockAdapter(clock: clock)
    )
    client.track(event("a"))
    await client.waitUntilIdle()
    #expect(client.pendingCount == 1, "Kept for a later retry")

    client.track(event("b"))
    await client.waitUntilIdle()
    #expect(transport.requests.count == 1, "Backing off: no new request yet")

    clock.advance(31)
    client.flush()
    await client.waitUntilIdle()
    #expect(transport.requests.count == 2)
    #expect(transport.batches.last?.count == 2, "The retried batch carries both events")
    #expect(client.pendingCount == 0)
}

@Test func rejectedBatchIsDroppedRatherThanRetriedForever() async {
    let transport = FakeTransport(results: [.rejected])
    let client = PostHogAnalyticsClient(configuration: configuration(flushAt: 1), transport: transport)
    client.track(event("a"))
    await client.waitUntilIdle()
    #expect(client.pendingCount == 0)
}

@Test func largeBacklogDrainsInBatches() async {
    let transport = FakeTransport(results: [.retryLater])
    let clock = TestClock()
    let client = PostHogAnalyticsClient(
        configuration: configuration(flushAt: 2, maxBatchSize: 2), transport: transport, clock: ClockAdapter(clock: clock)
    )
    for index in 0..<5 { client.track(event("e\(index)", seq: index)) }
    await client.waitUntilIdle()
    clock.advance(31)
    client.flush()
    await client.waitUntilIdle()
    let sizes = transport.batches.map(\.count)
    #expect(sizes == [2, 2, 2, 1], "One failed attempt, then the backlog drains two at a time")
    #expect(client.pendingCount == 0)
}

@Test func queueIsBoundedAndDropsTheOldest() async {
    let transport = FakeTransport(results: Array(repeating: .retryLater, count: 10))
    let client = PostHogAnalyticsClient(
        configuration: configuration(flushAt: 1_000, maxBatchSize: 3, maxQueuedEvents: 3), transport: transport
    )
    for index in 0..<5 { client.track(event("e\(index)", seq: index)) }
    #expect(client.pendingCount == 3)
    client.flush()
    await client.waitUntilIdle()
    #expect(transport.batches.first?.map { $0["event"] as? String } == ["e2", "e3", "e4"])
}

@Test func queuedEventsSurviveARelaunch() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("gametime-\(UUID().uuidString)/posthog-queue.json")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let offline = FakeTransport(results: [.retryLater])
    let first = PostHogAnalyticsClient(configuration: configuration(flushAt: 1), transport: offline, queueFileURL: url)
    first.track(event("a"))
    await first.waitUntilIdle()

    let online = FakeTransport()
    let second = PostHogAnalyticsClient(configuration: configuration(flushAt: 1), transport: online, queueFileURL: url)
    #expect(second.pendingCount == 1)
    second.flush()
    await second.waitUntilIdle()
    #expect(online.batches.first?.first?["event"] as? String == "a")
    #expect(second.pendingCount == 0)
}

@Test func httpStatusesMapToDeliveryResults() {
    #expect(URLSessionAnalyticsTransport.result(forStatus: 200) == .delivered)
    #expect(URLSessionAnalyticsTransport.result(forStatus: 429) == .retryLater)
    #expect(URLSessionAnalyticsTransport.result(forStatus: 503) == .retryLater)
    #expect(URLSessionAnalyticsTransport.result(forStatus: 400) == .rejected)
    #expect(URLSessionAnalyticsTransport.result(forStatus: 401) == .rejected)
}
