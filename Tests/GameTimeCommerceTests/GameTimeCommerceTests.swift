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
    #expect(outcomes.filter { $0 == .alreadyGranted }.count == 1)
    #expect(await provider.presentations() == 1)
    #expect(await receipts.transactions().count == 1)
}
