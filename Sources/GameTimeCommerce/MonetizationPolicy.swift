import Foundation

public enum MonetizationPlacement: String, Codable, CaseIterable, Sendable {
    case rewardedHint
    case rewardedContinue
    case bonusReward
    case betweenLevels

    public var isRewarded: Bool {
        switch self {
        case .rewardedHint, .rewardedContinue, .bonusReward:
            true
        case .betweenLevels:
            false
        }
    }
}

public struct MonetizationContext: Equatable, Sendable {
    public var isGloballyEnabled: Bool
    public var isOnboarding: Bool
    public var sessionAge: TimeInterval
    public var completedLevels: Int
    public var lastNonRewardedAdAt: Date?
    public var hasRemoveAdsEntitlement: Bool

    public init(
        isGloballyEnabled: Bool = true,
        isOnboarding: Bool,
        sessionAge: TimeInterval,
        completedLevels: Int,
        lastNonRewardedAdAt: Date? = nil,
        hasRemoveAdsEntitlement: Bool = false
    ) {
        self.isGloballyEnabled = isGloballyEnabled
        self.isOnboarding = isOnboarding
        self.sessionAge = sessionAge
        self.completedLevels = completedLevels
        self.lastNonRewardedAdAt = lastNonRewardedAdAt
        self.hasRemoveAdsEntitlement = hasRemoveAdsEntitlement
    }
}

public struct MonetizationPolicyConfiguration: Equatable, Sendable {
    public var nonRewardedMinimumSessionAge: TimeInterval
    public var nonRewardedMinimumCompletedLevels: Int
    public var nonRewardedCooldown: TimeInterval

    public init(
        nonRewardedMinimumSessionAge: TimeInterval = 180,
        nonRewardedMinimumCompletedLevels: Int = 5,
        nonRewardedCooldown: TimeInterval = 300
    ) {
        self.nonRewardedMinimumSessionAge = max(0, nonRewardedMinimumSessionAge)
        self.nonRewardedMinimumCompletedLevels = max(0, nonRewardedMinimumCompletedLevels)
        self.nonRewardedCooldown = max(0, nonRewardedCooldown)
    }
}

public enum MonetizationIneligibilityReason: String, Equatable, Sendable {
    case globallyDisabled
    case onboarding
    case removeAdsEntitlement
    case sessionTooYoung
    case insufficientProgress
    case cooldown
}

public enum MonetizationEligibility: Equatable, Sendable {
    case eligible
    case ineligible(MonetizationIneligibilityReason)
}

/// Central, deterministic ad eligibility policy.
///
/// Rewarded placements are intentionally lightweight because the player opts into
/// a value exchange. Non-rewarded placements are protected by progress, session,
/// cooldown and Remove Ads gates.
public struct MonetizationPolicy: Sendable {
    public let configuration: MonetizationPolicyConfiguration

    public init(configuration: MonetizationPolicyConfiguration = .init()) {
        self.configuration = configuration
    }

    public func eligibility(
        for placement: MonetizationPlacement,
        context: MonetizationContext,
        now: Date = Date()
    ) -> MonetizationEligibility {
        guard context.isGloballyEnabled else {
            return .ineligible(.globallyDisabled)
        }
        guard !context.isOnboarding else {
            return .ineligible(.onboarding)
        }

        if placement.isRewarded {
            return .eligible
        }

        guard !context.hasRemoveAdsEntitlement else {
            return .ineligible(.removeAdsEntitlement)
        }
        guard context.sessionAge >= configuration.nonRewardedMinimumSessionAge else {
            return .ineligible(.sessionTooYoung)
        }
        guard context.completedLevels >= configuration.nonRewardedMinimumCompletedLevels else {
            return .ineligible(.insufficientProgress)
        }
        if let lastShown = context.lastNonRewardedAdAt,
           now.timeIntervalSince(lastShown) < configuration.nonRewardedCooldown {
            return .ineligible(.cooldown)
        }
        return .eligible
    }
}

public enum AdPresentationResult: Equatable, Sendable {
    case completed
    case cancelled
    case unavailable
}

/// Provider-agnostic ad boundary. Provider SDK objects must not cross this API.
public protocol AdProviding: Sendable {
    func isAvailable(for placement: MonetizationPlacement) async -> Bool
    func present(_ placement: MonetizationPlacement) async throws -> AdPresentationResult
}

public struct NoOpAdProvider: AdProviding {
    public init() {}

    public func isAvailable(for placement: MonetizationPlacement) async -> Bool {
        false
    }

    public func present(_ placement: MonetizationPlacement) async throws -> AdPresentationResult {
        .unavailable
    }
}

public enum MonetizationEvent: Equatable, Sendable {
    case offerEligible(MonetizationPlacement)
    case offerIneligible(MonetizationPlacement, MonetizationIneligibilityReason)
    case presentationStarted(MonetizationPlacement)
    case presentationCompleted(MonetizationPlacement)
    case presentationCancelled(MonetizationPlacement)
    case presentationUnavailable(MonetizationPlacement)
    case presentationFailed(MonetizationPlacement)
    case rewardGranted(MonetizationPlacement, rewardID: String)
}

public protocol MonetizationEventTracking: Sendable {
    func track(_ event: MonetizationEvent) async
}

public struct NoOpMonetizationEventTracker: MonetizationEventTracking {
    public init() {}
    public func track(_ event: MonetizationEvent) async {}
}
