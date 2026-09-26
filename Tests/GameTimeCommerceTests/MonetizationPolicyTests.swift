import XCTest
@testable import GameTimeCommerce

final class MonetizationPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    func testOnboardingSuppressesRewardedPlacements() {
        let policy = MonetizationPolicy()
        let context = MonetizationContext(canRequestAds: true, 
            isOnboarding: true,
            sessionAge: 600,
            completedLevels: 20
        )

        XCTAssertEqual(
            policy.eligibility(for: .rewardedHint, context: context, now: now),
            .ineligible(.onboarding)
        )
    }

    func testRewardedHintIsEligibleAfterOnboardingWithoutInterstitialGates() {
        let policy = MonetizationPolicy()
        let context = MonetizationContext(canRequestAds: true, 
            isOnboarding: false,
            sessionAge: 5,
            completedLevels: 0
        )

        XCTAssertEqual(
            policy.eligibility(for: .rewardedHint, context: context, now: now),
            .eligible
        )
    }

    func testNonRewardedPlacementRequiresProgressAndSessionAge() {
        let policy = MonetizationPolicy(
            configuration: .init(
                nonRewardedMinimumSessionAge: 180,
                nonRewardedMinimumCompletedLevels: 5,
                nonRewardedCooldown: 300
            )
        )

        let youngSession = MonetizationContext(canRequestAds: true, 
            isOnboarding: false,
            sessionAge: 60,
            completedLevels: 10
        )
        XCTAssertEqual(
            policy.eligibility(for: .betweenLevels, context: youngSession, now: now),
            .ineligible(.sessionTooYoung)
        )

        let lowProgress = MonetizationContext(canRequestAds: true, 
            isOnboarding: false,
            sessionAge: 600,
            completedLevels: 2
        )
        XCTAssertEqual(
            policy.eligibility(for: .betweenLevels, context: lowProgress, now: now),
            .ineligible(.insufficientProgress)
        )
    }

    func testRemoveAdsSuppressesOnlyNonRewardedPlacements() {
        let policy = MonetizationPolicy()
        let context = MonetizationContext(canRequestAds: true, 
            isOnboarding: false,
            sessionAge: 600,
            completedLevels: 20,
            hasRemoveAdsEntitlement: true
        )

        XCTAssertEqual(
            policy.eligibility(for: .betweenLevels, context: context, now: now),
            .ineligible(.removeAdsEntitlement)
        )
        XCTAssertEqual(
            policy.eligibility(for: .rewardedHint, context: context, now: now),
            .eligible
        )
    }

    func testCooldownSuppressesRepeatedNonRewardedAds() {
        let policy = MonetizationPolicy(
            configuration: .init(nonRewardedCooldown: 300)
        )
        let context = MonetizationContext(canRequestAds: true, 
            isOnboarding: false,
            sessionAge: 600,
            completedLevels: 20,
            lastNonRewardedAdAt: now.addingTimeInterval(-120)
        )

        XCTAssertEqual(
            policy.eligibility(for: .betweenLevels, context: context, now: now),
            .ineligible(.cooldown)
        )
    }

    func testGlobalKillSwitchWins() {
        let policy = MonetizationPolicy()
        let context = MonetizationContext(
            isGloballyEnabled: false, canRequestAds: true,
            isOnboarding: false,
            sessionAge: 600,
            completedLevels: 20
        )

        XCTAssertEqual(
            policy.eligibility(for: .rewardedHint, context: context, now: now),
            .ineligible(.globallyDisabled)
        )
    }
}
