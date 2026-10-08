#if canImport(GoogleMobileAds) && canImport(UIKit)
import Foundation
import UIKit
import UserMessagingPlatform

/// Google's User Messaging Platform consent flow. Ads may only be requested once consent
/// allows it; feed `canRequestAds` into `MonetizationContext`.
@MainActor
public final class AdConsent {
    public init() {}

    public var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    /// Whether the player should be offered a way to revisit their choice (for example in settings).
    public var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// Updates consent status and shows the consent form if one is required. Failures leave
    /// `canRequestAds` as the SDK reports it; they never throw into gameplay.
    @discardableResult
    public func gatherConsent(testDeviceIdentifiers: [String] = []) async -> Bool {
        let parameters = RequestParameters()
        if !testDeviceIdentifiers.isEmpty {
            let debug = DebugSettings()
            debug.testDeviceIdentifiers = testDeviceIdentifiers
            parameters.debugSettings = debug
        }
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: Self.topViewController())
        } catch {
            // Offline or form failure: fall through to whatever the SDK already knows.
        }
        return canRequestAds
    }

    public func presentPrivacyOptions() async {
        try? await ConsentForm.presentPrivacyOptionsForm(from: Self.topViewController())
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
