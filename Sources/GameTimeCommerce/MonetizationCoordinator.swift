import Foundation

public enum MonetizationOutcome: Equatable, Sendable {
    case ineligible(MonetizationIneligibilityReason)
    case busy
    case unavailable
    case cancelled
    case failed
    case alreadyGranted
    case granted(RewardTransaction)
}

/// Own one instance per app session. Reserves presentation before any suspension;
/// provider completion means an earned reward, never merely a dismissed ad.
public actor MonetizationCoordinator {
    private let provider: any AdProviding
    private let receipts: any RewardReceiptPersisting
    private let tracker: any MonetizationEventTracking
    private let policy: MonetizationPolicy
    private let now: @Sendable () -> Date
    private var presenting = false
    private var lastRewardAt: Date?

    public init(provider: any AdProviding, receipts: any RewardReceiptPersisting,
                tracker: any MonetizationEventTracking = NoOpMonetizationEventTracker(),
                policy: MonetizationPolicy = .init(),
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.provider = provider
        self.receipts = receipts
        self.tracker = tracker
        self.policy = policy
        self.now = now
    }

    public func attempt(_ request: RewardRequest, placement: MonetizationPlacement,
                        context: MonetizationContext) async -> MonetizationOutcome {
        guard !presenting else { return .busy }
        guard placement.isRewarded, request.offer.amount > 0, !request.id.isEmpty else { return .failed }
        presenting = true
        defer { presenting = false }
        var context = context
        context.lastRewardedAdAt = lastRewardAt ?? context.lastRewardedAdAt
        if case let .ineligible(reason) = policy.eligibility(for: placement, context: context, now: now()) {
            await tracker.track(.offerIneligible(placement, reason))
            return .ineligible(reason)
        }
        if await receipts.contains(rewardID: request.id) { return .alreadyGranted }
        await tracker.track(.offerEligible(placement))
        guard !Task.isCancelled, await provider.isAvailable(for: placement) else {
            await tracker.track(.presentationUnavailable(placement))
            return .unavailable
        }
        await tracker.track(.presentationStarted(placement))
        do {
            switch try await provider.present(placement) {
            case .cancelled:
                await tracker.track(.presentationCancelled(placement))
                return .cancelled
            case .unavailable:
                await tracker.track(.presentationUnavailable(placement))
                return .unavailable
            case .completed:
                await tracker.track(.presentationCompleted(placement))
                let transaction = RewardTransaction(rewardID: request.id, offerID: request.offer.id, grantedAt: now())
                guard try await receipts.record(transaction) else { return .alreadyGranted }
                lastRewardAt = transaction.grantedAt
                await tracker.track(.rewardGranted(placement, rewardID: request.id))
                return .granted(transaction)
            }
        } catch {
            await tracker.track(.presentationFailed(placement))
            return .failed
        }
    }
}
