import GameTimeCommerce
import XCTest
@testable import GameTimeAdMob

final class AdMobConfigurationTests: XCTestCase {
    func testTestingConfigurationCoversEveryRewardedPlacementAndNothingElse() {
        let configuration = AdMobConfiguration.testing
        for placement in MonetizationPlacement.allCases {
            if placement.isRewarded {
                XCTAssertEqual(
                    configuration.rewardedUnitID(for: placement),
                    AdMobConfiguration.sampleRewardedUnitID,
                    "\(placement) should use the sample rewarded unit"
                )
            } else {
                XCTAssertNil(configuration.rewardedUnitID(for: placement), "\(placement) is not rewarded")
            }
        }
    }

    func testNonRewardedPlacementNeverResolvesAUnitEvenIfConfigured() {
        let configuration = AdMobConfiguration(rewardedUnitIDs: [.betweenLevels: "ca-app-pub-x/y"])
        XCTAssertNil(configuration.rewardedUnitID(for: .betweenLevels))
    }

    func testMissingPlacementHasNoUnit() {
        let configuration = AdMobConfiguration(rewardedUnitIDs: [.rewardedHint: "ca-app-pub-x/hint"])
        XCTAssertEqual(configuration.rewardedUnitID(for: .rewardedHint), "ca-app-pub-x/hint")
        XCTAssertNil(configuration.rewardedUnitID(for: .rewardedContinue))
    }
}
