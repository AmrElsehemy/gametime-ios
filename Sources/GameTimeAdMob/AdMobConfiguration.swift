import Foundation
import GameTimeCommerce

/// Which AdMob ad unit serves each placement. Games supply their own production unit ids;
/// `.testing` uses Google's public sample units, which are always safe to load and tap.
public struct AdMobConfiguration: Sendable, Equatable {
    public var rewardedUnitIDs: [MonetizationPlacement: String]
    /// Hashed device ids that should receive test ads even with production units.
    public var testDeviceIdentifiers: [String]

    public init(
        rewardedUnitIDs: [MonetizationPlacement: String],
        testDeviceIdentifiers: [String] = []
    ) {
        self.rewardedUnitIDs = rewardedUnitIDs
        self.testDeviceIdentifiers = testDeviceIdentifiers
    }

    /// Google's documented sample rewarded unit. Never ship it in a release build.
    public static let sampleRewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

    /// Google's documented sample application id, for the `GADApplicationIdentifier` Info.plist key.
    public static let sampleApplicationID = "ca-app-pub-3940256099942544~1458002511"

    public static let testing = AdMobConfiguration(
        rewardedUnitIDs: Dictionary(
            uniqueKeysWithValues: MonetizationPlacement.allCases
                .filter(\.isRewarded)
                .map { ($0, sampleRewardedUnitID) }
        )
    )

    public func rewardedUnitID(for placement: MonetizationPlacement) -> String? {
        guard placement.isRewarded else { return nil }
        return rewardedUnitIDs[placement]
    }
}
