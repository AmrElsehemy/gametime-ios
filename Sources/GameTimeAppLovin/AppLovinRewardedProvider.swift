#if canImport(AppLovinSDK) && canImport(UIKit)
import AppLovinSDK
import Foundation
import GameTimeCommerce
import UIKit

/// Rewarded ads through AppLovin MAX, behind `AdProviding`. SDK objects never leave this type. One
/// ad is preloaded per placement so `isAvailable` is an instant, honest answer, and a failed load
/// never blocks play: it simply reports `unavailable`.
///
/// Consent is MAX's built-in terms and privacy-policy flow (Google UMP under the hood), which runs
/// during SDK initialisation, so there is no separate consent step: call `start()` at launch.
public final class AppLovinRewardedProvider: AdProviding, @unchecked Sendable {
    private let configuration: AppLovinConfiguration
    private let store: AppLovinAdStore

    public init(configuration: AppLovinConfiguration) {
        self.configuration = configuration
        self.store = MainActor.assumeIsolated { AppLovinAdStore(configuration: configuration) }
    }

    /// Initialises the SDK (showing the consent flow if the player's region needs one) and begins
    /// preloading. Call once at launch. Does nothing if the configuration has no key or units.
    @MainActor
    public func start() async {
        guard configuration.isConfigured else { return }
        let sdk = ALSdk.shared()
        let flow = sdk.settings.termsAndPrivacyPolicyFlowSettings
        flow.isEnabled = configuration.privacyPolicyURL != nil
        flow.privacyPolicyURL = configuration.privacyPolicyURL
        flow.termsOfServiceURL = configuration.termsOfServiceURL
        let initialization = ALSdkInitializationConfiguration(sdkKey: configuration.sdkKey) { builder in
            builder.mediationProvider = ALMediationProviderMAX
            builder.testDeviceAdvertisingIdentifiers = self.configuration.testDeviceAdvertisingIdentifiers
            builder.adUnitIdentifiers = MonetizationPlacement.allCases.compactMap {
                self.configuration.rewardedUnitID(for: $0)
            }
        }
        await withCheckedContinuation { continuation in
            sdk.initialize(with: initialization) { _ in continuation.resume() }
        }
        store.preloadAll()
    }

    /// Whether the player should be offered a way to revisit their consent choice (for settings).
    @MainActor
    public var privacyOptionsRequired: Bool {
        configuration.isConfigured && ALSdk.shared().cmpService.hasSupportedCMP()
    }

    @MainActor
    public func presentPrivacyOptions() async {
        guard privacyOptionsRequired else { return }
        await withCheckedContinuation { continuation in
            ALSdk.shared().cmpService.showCMPForExistingUser { _ in continuation.resume() }
        }
    }

    public func isAvailable(for placement: MonetizationPlacement) async -> Bool {
        await store.isReady(placement)
    }

    public func present(_ placement: MonetizationPlacement) async throws -> AdPresentationResult {
        await store.present(placement)
    }
}

/// Owns one `RewardedController` per rewarded placement.
@MainActor
private final class AppLovinAdStore {
    private var controllers: [MonetizationPlacement: RewardedController] = [:]

    init(configuration: AppLovinConfiguration) {
        for placement in MonetizationPlacement.allCases {
            if let id = configuration.rewardedUnitID(for: placement) {
                controllers[placement] = RewardedController(unitID: id)
            }
        }
    }

    func preloadAll() {
        controllers.values.forEach { $0.load() }
    }

    func isReady(_ placement: MonetizationPlacement) -> Bool {
        controllers[placement]?.isReady ?? false
    }

    func present(_ placement: MonetizationPlacement) async -> AdPresentationResult {
        guard let controller = controllers[placement] else { return .unavailable }
        return await controller.present()
    }
}

/// One MAX rewarded ad unit. Earning the reward and closing the ad arrive as separate callbacks;
/// only an earned reward counts as `completed`. MAX keeps the delegate weakly, so this is retained
/// by the store. Failed loads retry with exponential backoff, as MAX recommends.
@MainActor
private final class RewardedController: NSObject, @preconcurrency MARewardedAdDelegate {
    private let ad: MARewardedAd
    private var earned = false
    private var retryAttempt = 0
    private var continuation: CheckedContinuation<AdPresentationResult, Never>?

    init(unitID: String) {
        ad = MARewardedAd.shared(withAdUnitIdentifier: unitID)
        super.init()
        ad.delegate = self
    }

    var isReady: Bool { ad.isReady }

    func load() {
        ad.load()
    }

    func present() async -> AdPresentationResult {
        guard ad.isReady, continuation == nil else {
            if !ad.isReady { load() }
            return .unavailable
        }
        earned = false
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            ad.show()
        }
    }

    private func finish(_ result: AdPresentationResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }

    func didLoad(_ ad: MAAd) {
        retryAttempt = 0
    }

    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        retryAttempt += 1
        let delay = pow(2.0, Double(min(retryAttempt, 6)))
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            self?.load()
        }
    }

    func didRewardUser(for ad: MAAd, with reward: MAReward) {
        earned = true
    }

    func didHide(_ ad: MAAd) {
        finish(earned ? .completed : .cancelled)
        load()
    }

    func didFail(toDisplay ad: MAAd, withError error: MAError) {
        finish(.unavailable)
        load()
    }

    func didDisplay(_ ad: MAAd) {}
    func didClick(_ ad: MAAd) {}
}
#endif
