import Foundation
import GameTimeCommerce

/// Which AppLovin MAX ad unit serves each placement, plus the SDK key and consent-flow URLs.
/// Unlike AdMob, MAX has no public sample units: use your real units and list your devices in
/// `testDeviceAdvertisingIdentifiers` (or turn on Test Mode in the MAX dashboard) to get test ads.
public struct AppLovinConfiguration: Sendable, Equatable {
    public var sdkKey: String
    public var rewardedUnitIDs: [MonetizationPlacement: String]
    /// IDFAs of devices that should receive test ads even with production units.
    public var testDeviceAdvertisingIdentifiers: [String]
    /// Shown in MAX's built-in consent flow. Required for the flow to run.
    public var privacyPolicyURL: URL?
    public var termsOfServiceURL: URL?

    public init(
        sdkKey: String,
        rewardedUnitIDs: [MonetizationPlacement: String],
        testDeviceAdvertisingIdentifiers: [String] = [],
        privacyPolicyURL: URL? = nil,
        termsOfServiceURL: URL? = nil
    ) {
        self.sdkKey = sdkKey
        self.rewardedUnitIDs = rewardedUnitIDs
        self.testDeviceAdvertisingIdentifiers = testDeviceAdvertisingIdentifiers
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfServiceURL = termsOfServiceURL
    }

    /// No SDK key or no rewarded unit means there is nothing to show, so the provider stays inert.
    public var isConfigured: Bool {
        !sdkKey.isEmpty && MonetizationPlacement.allCases.contains { rewardedUnitID(for: $0) != nil }
    }

    public func rewardedUnitID(for placement: MonetizationPlacement) -> String? {
        guard placement.isRewarded, let id = rewardedUnitIDs[placement], !id.isEmpty else { return nil }
        return id
    }
}
