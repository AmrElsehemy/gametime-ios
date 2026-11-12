import GameTimeCommerce
import XCTest
@testable import GameTimeAppLovin

final class AppLovinConfigurationTests: XCTestCase {
    func testNonRewardedPlacementNeverResolvesAUnitEvenIfConfigured() {
        let configuration = AppLovinConfiguration(sdkKey: "key", rewardedUnitIDs: [.betweenLevels: "unit"])
        XCTAssertNil(configuration.rewardedUnitID(for: .betweenLevels))
    }

    func testMissingOrEmptyPlacementHasNoUnit() {
        let configuration = AppLovinConfiguration(
            sdkKey: "key",
            rewardedUnitIDs: [.rewardedHint: "hint", .rewardedContinue: ""]
        )
        XCTAssertEqual(configuration.rewardedUnitID(for: .rewardedHint), "hint")
        XCTAssertNil(configuration.rewardedUnitID(for: .rewardedContinue))
    }

    func testIsConfiguredNeedsAKeyAndARewardedUnit() {
        XCTAssertFalse(AppLovinConfiguration(sdkKey: "", rewardedUnitIDs: [.rewardedHint: "unit"]).isConfigured)
        XCTAssertFalse(AppLovinConfiguration(sdkKey: "key", rewardedUnitIDs: [:]).isConfigured)
        XCTAssertFalse(AppLovinConfiguration(sdkKey: "key", rewardedUnitIDs: [.betweenLevels: "unit"]).isConfigured)
        XCTAssertTrue(AppLovinConfiguration(sdkKey: "key", rewardedUnitIDs: [.rewardedHint: "unit"]).isConfigured)
    }
}
