#if canImport(GoogleMobileAds) && canImport(UIKit)
import Foundation
import GameTimeCommerce
import GoogleMobileAds
import UIKit

/// Rewarded ads through Google Mobile Ads, behind `AdProviding`. SDK objects never leave this
/// type. One ad is preloaded per placement so `isAvailable` is an instant, honest answer, and a
/// failed load never blocks play: it simply reports `unavailable`.
public final class AdMobRewardedProvider: AdProviding, @unchecked Sendable {
    private let configuration: AdMobConfiguration

    public init(configuration: AdMobConfiguration) {
        self.configuration = configuration
    }

    /// Starts the SDK and begins preloading. Call once after consent allows ad requests.
    @MainActor
    public func start() {
        if !configuration.testDeviceIdentifiers.isEmpty {
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = configuration.testDeviceIdentifiers
        }
        MobileAds.shared.start(completionHandler: nil)
        for placement in MonetizationPlacement.allCases where placement.isRewarded {
            Task { await AdStore.shared.preload(placement, unitID: configuration.rewardedUnitID(for: placement)) }
        }
    }

    public func isAvailable(for placement: MonetizationPlacement) async -> Bool {
        await AdStore.shared.hasAd(for: placement)
    }

    public func present(_ placement: MonetizationPlacement) async throws -> AdPresentationResult {
        let unitID = configuration.rewardedUnitID(for: placement)
        guard let session = await AdStore.shared.take(placement) else {
            // Nothing ready: try to have one for next time, and tell the caller honestly.
            Task { await AdStore.shared.preload(placement, unitID: unitID) }
            return .unavailable
        }
        let result = await session.present()
        Task { await AdStore.shared.preload(placement, unitID: unitID) }
        return result
    }
}

/// Holds at most one loaded ad per placement.
@MainActor
private final class AdStore {
    static let shared = AdStore()

    private var loaded: [MonetizationPlacement: RewardedSession] = [:]
    private var loading: Set<MonetizationPlacement> = []

    func hasAd(for placement: MonetizationPlacement) -> Bool {
        loaded[placement] != nil
    }

    func take(_ placement: MonetizationPlacement) -> RewardedSession? {
        loaded.removeValue(forKey: placement)
    }

    func preload(_ placement: MonetizationPlacement, unitID: String?) async {
        guard let unitID, loaded[placement] == nil, !loading.contains(placement) else { return }
        loading.insert(placement)
        defer { loading.remove(placement) }
        do {
            let ad = try await RewardedAd.load(with: unitID, request: Request())
            loaded[placement] = RewardedSession(ad: ad)
        } catch {
            // Offline or no fill. The next present/preload attempt retries.
        }
    }
}

/// One presentation of one loaded ad. Earning the reward and closing the ad arrive as separate
/// callbacks; only an earned reward counts as `completed`.
@MainActor
private final class RewardedSession: NSObject, FullScreenContentDelegate {
    private let ad: RewardedAd
    private var earned = false
    private var continuation: CheckedContinuation<AdPresentationResult, Never>?

    init(ad: RewardedAd) {
        self.ad = ad
        super.init()
        ad.fullScreenContentDelegate = self
    }

    func present() async -> AdPresentationResult {
        guard let controller = Self.topViewController() else { return .unavailable }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            ad.present(from: controller) { [weak self] in
                self?.earned = true
            }
        }
    }

    private func finish(_ result: AdPresentationResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finish(earned ? .completed : .cancelled)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        finish(.unavailable)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif
