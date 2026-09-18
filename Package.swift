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
        .library(name: "GameTimeTesting", targets: ["GameTimeTesting"])
    ],
    targets: [
        .target(name: "GameTimeCore"),
        .target(name: "GameTimeExperience", dependencies: ["GameTimeCore"]),
        .target(name: "GameTimeServices", dependencies: ["GameTimeCore"]),
        .target(name: "GameTimeCommerce", dependencies: ["GameTimeCore", "GameTimeServices"]),
        .target(name: "GameTimeTesting", dependencies: ["GameTimeCore", "GameTimeServices", "GameTimeCommerce"]),
        .testTarget(name: "GameTimeCoreTests", dependencies: ["GameTimeCore", "GameTimeTesting"])
    ]
)
