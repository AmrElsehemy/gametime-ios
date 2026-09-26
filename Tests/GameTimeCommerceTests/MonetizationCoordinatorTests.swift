import Foundation
import Testing
@testable import GameTimeCommerce

private actor SuspendedAdProvider: AdProviding {
    var continuation: CheckedContinuation<AdPresentationResult, Never>?
    var presentations = 0
    func isAvailable(for placement: MonetizationPlacement) async -> Bool { true }
    func present(_ placement: MonetizationPlacement) async throws -> AdPresentationResult {
        presentations += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish(_ result: AdPresentationResult) { continuation?.resume(returning: result); continuation = nil }
    var waiting: Bool { continuation != nil }
}

private let reward = RewardRequest(id: "attempt:continue", offer: .init(id: "continue", kind: "seconds", amount: 15))
private let allowed = MonetizationContext(canRequestAds: true, isOnboarding: false, sessionAge: 10, completedLevels: 5)

@Test func concurrentPresentationIsRejectedAndRewardIsExactlyOnce() async {
    let provider = SuspendedAdProvider()
    let receipts = InMemoryRewardReceiptStore()
    let coordinator = MonetizationCoordinator(provider: provider, receipts: receipts,
        policy: .init(configuration: .init(rewardedCooldown: 0)))
    let first = Task { await coordinator.attempt(reward, placement: .rewardedContinue, context: allowed) }
    while !(await provider.waiting) { await Task.yield() }
    #expect(await coordinator.attempt(reward, placement: .rewardedContinue, context: allowed) == .busy)
    await provider.finish(.completed)
    guard case .granted = await first.value else { Issue.record("Missing reward"); return }
    #expect(await coordinator.attempt(reward, placement: .rewardedContinue, context: allowed) == .alreadyGranted)
    #expect(await provider.presentations == 1)
    #expect(await receipts.transactions().count == 1)
}

@Test func cancellationDoesNotGrantAndAllowsRetry() async {
    let provider = SuspendedAdProvider()
    let receipts = InMemoryRewardReceiptStore()
    let coordinator = MonetizationCoordinator(provider: provider, receipts: receipts)
    for _ in 0..<2 {
        let attempt = Task { await coordinator.attempt(reward, placement: .rewardedContinue, context: allowed) }
        while !(await provider.waiting) { await Task.yield() }
        await provider.finish(.cancelled)
        #expect(await attempt.value == .cancelled)
    }
    #expect(await receipts.transactions().isEmpty)
}

@Test func consentDefaultsToDeniedAndRewardFrequencyIsCentral() {
    let policy = MonetizationPolicy()
    var context = MonetizationContext(isOnboarding: false, sessionAge: 100, completedLevels: 10)
    #expect(policy.eligibility(for: .rewardedContinue, context: context) == .ineligible(.consentRequired))
    context.canRequestAds = true
    let now = Date(timeIntervalSince1970: 100)
    context.lastRewardedAdAt = now
    #expect(policy.eligibility(for: .rewardedHint, context: context, now: now) == .ineligible(.cooldown))
    #expect(policy.eligibility(for: .rewardedHint, context: context, now: now.addingTimeInterval(30)) == .eligible)
}
