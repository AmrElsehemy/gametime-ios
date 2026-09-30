import Foundation
import Testing
@testable import GameTimeCommerce

private actor TestRewardedAdProvider: RewardedAdProviding {
    var available: Bool
    var shouldReward: Bool
    private(set) var presentCount = 0

    init(available: Bool = true, shouldReward: Bool = true) {
        self.available = available
        self.shouldReward = shouldReward
    }

    func isAvailable(for offer: RewardOffer) async -> Bool {
        available
    }

    func present(offer: RewardOffer) async throws -> Bool {
        presentCount += 1
        return shouldReward
    }

    func presentations() async -> Int {
        presentCount
    }
}

@Test func unavailableRewardDoesNotPresentOrGrant() async throws {
    let provider = TestRewardedAdProvider(available: false)
    let receipts = InMemoryRewardReceiptStore()
    let coordinator = RewardedAdCoordinator(
        provider: provider,
        receipts: receipts
    )
    let request = RewardRequest(
        id: "hint:v1-006:attempt-1",
        offer: RewardOffer(id: "rewarded-hint", kind: "hint")
    )

    let outcome = try await coordinator.attempt(request)

    #expect(outcome == .unavailable)
    #expect(await provider.presentations() == 0)
    #expect(await receipts.transactions().isEmpty)
}

@Test func completedAdWithoutRewardDoesNotGrant() async throws {
    let provider = TestRewardedAdProvider(shouldReward: false)
    let receipts = InMemoryRewardReceiptStore()
    let coordinator = RewardedAdCoordinator(
        provider: provider,
        receipts: receipts
    )
    let request = RewardRequest(
        id: "hint:v1-006:attempt-2",
        offer: RewardOffer(id: "rewarded-hint", kind: "hint")
    )

    let outcome = try await coordinator.attempt(request)

    #expect(outcome == .notEarned)
    #expect(await provider.presentations() == 1)
    #expect(await receipts.transactions().isEmpty)
}

@Test func sameRewardIdentifierCanOnlyGrantOnce() async throws {
    let provider = TestRewardedAdProvider()
    let receipts = InMemoryRewardReceiptStore()
    let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
    let coordinator = RewardedAdCoordinator(
        provider: provider,
        receipts: receipts,
        now: { fixedDate }
    )
    let request = RewardRequest(
        id: "hint:v1-006:attempt-3",
        offer: RewardOffer(id: "rewarded-hint", kind: "hint")
    )

    let first = try await coordinator.attempt(request)
    let second = try await coordinator.attempt(request)

    guard case let .granted(transaction) = first else {
        Issue.record("Expected the first attempt to grant")
        return
    }

    #expect(transaction.rewardID == request.id)
    #expect(transaction.offerID == request.offer.id)
    #expect(transaction.grantedAt == fixedDate)
    #expect(second == .alreadyGranted)
    #expect(await provider.presentations() == 1)
    #expect(await receipts.transactions().count == 1)
}

@Test func concurrentDuplicateAttemptsAreSerialized() async throws {
    let provider = TestRewardedAdProvider()
    let receipts = InMemoryRewardReceiptStore()
    let coordinator = RewardedAdCoordinator(
        provider: provider,
        receipts: receipts
    )
    let request = RewardRequest(
        id: "hint:v1-006:attempt-4",
        offer: RewardOffer(id: "rewarded-hint", kind: "hint")
    )

    async let first = coordinator.attempt(request)
    async let second = coordinator.attempt(request)
    let outcomes = try await [first, second]

    #expect(outcomes.filter {
        if case .granted = $0 { return true }
        return false
    }.count == 1)
    #expect(outcomes.filter { $0 == .alreadyGranted || $0 == .inProgress }.count == 1)
    #expect(await provider.presentations() == 1)
    #expect(await receipts.transactions().count == 1)
}

private struct ReceiptWriteFailure: Error {}

private actor FlakyReceiptStore: RewardReceiptPersisting {
    private let inner = InMemoryRewardReceiptStore()
    var failuresRemaining: Int
    private(set) var writeAttempts = 0

    init(failures: Int) {
        failuresRemaining = failures
    }

    func contains(rewardID: String) async -> Bool {
        await inner.contains(rewardID: rewardID)
    }

    func transaction(for rewardID: String) async -> RewardTransaction? {
        await inner.transaction(for: rewardID)
    }

    func record(_ transaction: RewardTransaction) async throws -> Bool {
        writeAttempts += 1
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw ReceiptWriteFailure()
        }
        return try await inner.record(transaction)
    }

    func stored() async -> [RewardTransaction] {
        await inner.transactions()
    }
}

@Test func earnedRewardSurvivesFailedReceiptWriteAndIsNotGrantedTwice() async throws {
    let provider = TestRewardedAdProvider()
    let receipts = FlakyReceiptStore(failures: 1)
    let coordinator = RewardedAdCoordinator(provider: provider, receipts: receipts)
    let request = RewardRequest(
        offer: RewardOffer(id: "rewarded-hint", kind: "hint"),
        opportunity: "level:v1-006:attempt:5"
    )

    let first = try await coordinator.attempt(request)
    guard case let .granted(transaction) = first else {
        Issue.record("An earned reward must be granted even when the receipt write fails")
        return
    }
    #expect(await receipts.stored().isEmpty)

    let retry = try await coordinator.attempt(request)

    #expect(retry == .alreadyGranted)
    #expect(await provider.presentations() == 1)
    #expect(await receipts.stored() == [transaction])
    #expect(await coordinator.grantedTransaction(for: request.id) == transaction)
}

@Test func alreadyGrantedRewardCanBeRecoveredByID() async throws {
    let provider = TestRewardedAdProvider()
    let receipts = InMemoryRewardReceiptStore()
    let coordinator = RewardedAdCoordinator(provider: provider, receipts: receipts)
    let request = RewardRequest(
        offer: RewardOffer(id: "rewarded-hint", kind: "hint"),
        opportunity: "level:v1-006:attempt:6"
    )

    guard case let .granted(transaction) = try await coordinator.attempt(request) else {
        Issue.record("Expected the first attempt to grant")
        return
    }

    #expect(try await coordinator.attempt(request) == .alreadyGranted)
    #expect(await coordinator.grantedTransaction(for: request.id) == transaction)
    #expect(await coordinator.grantedTransaction(for: "never-granted") == nil)
}

@Test func opportunityRequestsKeepTheSameIDAcrossRetries() {
    let offer = RewardOffer(id: "rewarded-hint", kind: "hint")

    let tap = RewardRequest(offer: offer, opportunity: "level:v1-006:attempt:7")
    let retry = RewardRequest(offer: offer, opportunity: "level:v1-006:attempt:7")
    let nextAttempt = RewardRequest(offer: offer, opportunity: "level:v1-006:attempt:8")

    #expect(tap.id == retry.id)
    #expect(tap.id != nextAttempt.id)
    #expect(tap.id == "rewarded-hint:level:v1-006:attempt:7")
}

@Test func storeSeededWithDuplicateRewardIDsKeepsEarliestGrant() async {
    let earlier = RewardTransaction(
        rewardID: "dup",
        offerID: "rewarded-hint",
        grantedAt: Date(timeIntervalSince1970: 100)
    )
    let later = RewardTransaction(
        rewardID: "dup",
        offerID: "rewarded-hint",
        grantedAt: Date(timeIntervalSince1970: 200)
    )

    let store = InMemoryRewardReceiptStore(transactions: [later, earlier])

    #expect(await store.transactions() == [earlier])
    #expect(await store.transaction(for: "dup") == earlier)
}
