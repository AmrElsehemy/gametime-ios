import Foundation
import GameTimeServices
import Testing
@testable import GameTimeAnalytics

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_800_000_000)
    var now: Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date = date.addingTimeInterval(seconds) } }
}

final class RecordingClient: AnalyticsClient, AnalyticsFlushing, @unchecked Sendable {
    private let lock = NSLock()
    private var received: [AnalyticsEvent] = []
    private var flushCount = 0
    var events: [AnalyticsEvent] { lock.withLock { received } }
    var flushes: Int { lock.withLock { flushCount } }
    func track(_ event: AnalyticsEvent) { lock.withLock { received.append(event) } }
    func flush() { lock.withLock { flushCount += 1 } }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> String { lock.withLock { value += 1; return "id-\(value)" } }
}

private let context = AnalyticsPipeline.Context(
    game: "test-game", appVersion: "1.0.0", build: "1", idiom: "phone", osMajor: "17", language: "en", schemaVersion: 3
)
private let menuOpened = AnalyticsEvent(name: "menu_opened")

private final class Harness {
    let clock = TestClock()
    let store = InMemoryEventStore()
    let client = RecordingClient()
    let suite = "gametime.analytics.tests.\(UUID().uuidString)"
    let pipeline: AnalyticsPipeline

    init(sharingByDefault: Bool = false) {
        let clock = clock
        let counter = Counter()
        pipeline = AnalyticsPipeline(
            store: store,
            clients: [client],
            context: context,
            keyPrefix: "test.analytics",
            sharingByDefault: sharingByDefault,
            suiteName: suite,
            now: { clock.now },
            makeID: { counter.next() }
        )
    }

    func events(_ name: String? = nil) -> [StoredEvent] {
        pipeline.flush()
        return store.all().filter { name == nil || $0.name == name }
    }

    deinit { UserDefaults.standard.removePersistentDomain(forName: suite) }
}

@Test func firstLaunchRecordsSessionStartThenFirstOpen() {
    let h = Harness()
    #expect(h.events().map(\.name) == ["session_start", "first_open"])
}

@Test func everyEventCarriesTheCommonFieldsAndASequence() {
    let h = Harness()
    h.pipeline.track(AnalyticsEvent(name: "level_started", properties: ["level_id": "4"]))
    let events = h.events()
    let last = events.last!
    #expect(last.name == "level_started")
    #expect(last.properties["level_id"] == "4")
    #expect(Set(last.properties.keys) == AnalyticsPipeline.commonPropertyKeys.union(["level_id"]))
    #expect(last.properties["game"] == "test-game")
    #expect(last.properties["schema"] == "3")
    let sequence = events.compactMap { $0.properties["seq"].flatMap(Int.init) }
    #expect(sequence == Array(1...events.count))
}

@Test func nothingIsForwardedUnlessSharingIsOn() {
    let h = Harness()
    h.pipeline.track(menuOpened)
    h.pipeline.flush()
    #expect(h.client.events.isEmpty, "Off by default: nothing leaves the device")
    #expect(!h.store.all().isEmpty, "...but it is still kept locally")

    h.pipeline.setSharingEnabled(true)
    h.pipeline.track(menuOpened)
    h.pipeline.flush()
    #expect(h.client.events.map(\.name) == ["menu_opened"])

    h.pipeline.setSharingEnabled(false)
    h.pipeline.track(menuOpened)
    h.pipeline.flush()
    #expect(h.client.events.count == 1)
}

@Test func sharingByDefaultForwardsUntilThePlayerOptsOut() {
    let h = Harness(sharingByDefault: true)
    h.pipeline.flush()
    #expect(h.client.events.map(\.name) == ["session_start", "first_open"])
    h.pipeline.setSharingEnabled(false)
    h.pipeline.track(menuOpened)
    h.pipeline.flush()
    #expect(h.client.events.count == 2)
}

@Test func sharingChoiceAndInstallIDSurviveARelaunch() {
    let suite = "gametime.analytics.tests.\(UUID().uuidString)"
    defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
    let first = AnalyticsPipeline(
        store: InMemoryEventStore(), context: context, keyPrefix: "p", sharingByDefault: true, suiteName: suite, makeID: { "install-A" }
    )
    first.setSharingEnabled(false)
    first.flush()
    let storeB = InMemoryEventStore()
    let second = AnalyticsPipeline(
        store: storeB, context: context, keyPrefix: "p", sharingByDefault: true, suiteName: suite, makeID: { "install-B" }
    )
    second.track(menuOpened)
    second.flush()
    #expect(!second.isSharingEnabled, "The player's choice beats the default")
    #expect(storeB.all().last?.properties["install_id"] == "install-A")
    #expect(!storeB.all().contains { $0.name == "first_open" }, "Only the first ever launch is a first_open")
}

@Test func aShortAbsenceContinuesTheSessionAndALongOneStartsANewOne() {
    let h = Harness()
    let firstSession = h.events("session_start").first!.properties["session_id"]
    h.pipeline.appDidEnterBackground()
    h.clock.advance(10 * 60)
    h.pipeline.appDidBecomeActive()
    h.pipeline.track(menuOpened)
    #expect(h.events("session_start").count == 1, "Ten minutes away is the same session")

    h.pipeline.noteLevelCompleted()
    h.pipeline.appDidEnterBackground()
    h.clock.advance(AnalyticsPipeline.sessionGap + 60)
    h.pipeline.appDidBecomeActive()
    let starts = h.events("session_start")
    #expect(starts.count == 2)
    #expect(starts.last!.properties["session_id"] != firstSession)
    let ended = h.events("session_end")
    #expect(ended.count == 1)
    #expect(ended[0].properties["session_id"] == firstSession, "The old session is closed under its own id")
    #expect(ended[0].properties["duration_s"] == "600")
    #expect(ended[0].properties["levels_completed"] == "1")
}

@Test func backgroundingAsksBufferingClientsToSend() {
    let h = Harness()
    h.pipeline.appDidEnterBackground()
    h.pipeline.flush()
    #expect(h.client.flushes == 1)
}

@Test func attemptsAreCountedPerKey() {
    let h = Harness()
    #expect(h.pipeline.nextAttempt(key: "campaign:1") == 1)
    #expect(h.pipeline.nextAttempt(key: "campaign:1") == 2)
    #expect(h.pipeline.nextAttempt(key: "daily:1") == 1)
}

@Test func fileStoreRoundTripsAndTrimsToItsLimit() {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("gametime-\(UUID().uuidString)/events.jsonl")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let store = FileEventStore(fileURL: url, maxEvents: 20)
    for index in 0..<30 {
        store.append(StoredEvent(name: "e\(index)", properties: ["seq": String(index)]))
    }
    let kept = store.all()
    #expect(kept.count <= 20)
    #expect(kept.last?.name == "e29", "The newest event is always kept")
    #expect(kept == kept.sorted { Int($0.properties["seq"]!)! < Int($1.properties["seq"]!)! }, "Order is preserved")

    store.clear()
    #expect(store.all().isEmpty)
}

@Test func pipelineCanStandInForAnyAnalyticsClient() {
    let h = Harness()
    let client: any AnalyticsClient = h.pipeline
    client.track(menuOpened)
    #expect(h.events().last?.name == "menu_opened")
}

@Test func anInstallThatPredatesAnalyticsIsNotCountedAsNew() {
    let suite = "gametime.analytics.tests.\(UUID().uuidString)"
    defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
    let store = InMemoryEventStore()
    let pipeline = AnalyticsPipeline(
        store: store, context: context, keyPrefix: "p", predatesAnalytics: true, suiteName: suite
    )
    pipeline.flush()
    #expect(store.all().map(\.name) == ["session_start"])
}
