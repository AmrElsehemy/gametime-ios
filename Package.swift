// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GameTimeKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "GameTimeCore", targets: ["GameTimeCore"]),
        .library(name: "GameTimeExperience", targets: ["GameTimeExperience"]),
        .library(name: "GameTimeServices", targets: ["GameTimeServices"]),
        .library(name: "GameTimeCommerce", targets: ["GameTimeCommerce"]),
        .library(name: "GameTimeAdMob", targets: ["GameTimeAdMob"]),
        .library(name: "GameTimeAppLovin", targets: ["GameTimeAppLovin"]),
        .library(name: "GameTimeTesting", targets: ["GameTimeTesting"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            from: "13.11.0"
        ),
        .package(url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git", from: "13.6.0")
    ],
    targets: [
        .target(name: "GameTimeCore"),
        .target(name: "GameTimeExperience", dependencies: ["GameTimeCore"]),
        .target(name: "GameTimeServices", dependencies: ["GameTimeCore"]),
        .target(name: "GameTimeCommerce", dependencies: ["GameTimeCore", "GameTimeServices"]),
        // Concrete AdMob adapter for the provider-agnostic `AdProviding` boundary. The SDK is
        // iOS-only, so macOS builds (`swift test`) compile an empty module.
        .target(
            name: "GameTimeAdMob",
            dependencies: [
                "GameTimeCommerce",
                .product(
                    name: "GoogleMobileAds",
                    package: "swift-package-manager-google-mobile-ads",
                    condition: .when(platforms: [.iOS])
                )
            ]
        ),
        // Concrete AppLovin MAX adapter for the same `AdProviding` boundary. iOS-only SDK, like AdMob.
        .target(
            name: "GameTimeAppLovin",
            dependencies: [
                "GameTimeCommerce",
                .product(
                    name: "AppLovinSDK",
                    package: "AppLovin-MAX-Swift-Package",
                    condition: .when(platforms: [.iOS])
                )
            ]
        ),
        .target(name: "GameTimeTesting", dependencies: ["GameTimeCore", "GameTimeServices", "GameTimeCommerce"]),
        .testTarget(name: "GameTimeCoreTests", dependencies: ["GameTimeCore", "GameTimeTesting"]),
        .testTarget(name: "GameTimeExperienceTests", dependencies: ["GameTimeExperience"]),
        .testTarget(name: "GameTimeCommerceTests", dependencies: ["GameTimeCommerce"]),
        .testTarget(name: "GameTimeAppLovinTests", dependencies: ["GameTimeAppLovin", "GameTimeCommerce"]),
        .testTarget(name: "GameTimeAdMobTests", dependencies: ["GameTimeAdMob", "GameTimeCommerce"])
    ]
)
