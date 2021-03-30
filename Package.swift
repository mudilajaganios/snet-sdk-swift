// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "snet-sdk-swift",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12)
    ],
    products: [
        .library(name: "snet-sdk-swift", targets: ["snet-sdk-swift", "snet_swift_pkg"])
    ],
    dependencies: [
        .package(name: "Web3", url: "https://github.com/Boilertalk/Web3.swift.git", from: "0.5.0"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.0.0")
    ],
    targets: [
        .binaryTarget(name: "snet_swift_pkg",
                      url: "https://github.com/singnet/snet-sdk-swift/releases/download/0.0.1/snet_swift_pkg0.0.1.zip",
                      checksum: "774f9ee91d73915c7868ffad26f4233b0af27ca6c02fe5b834cfccb808e731d1"),
        .target(
            name: "snet-sdk-swift",
            dependencies: [
                .target(name: "snet_swift_pkg"),
                .product(name: "Web3", package: "Web3"),
                .product(name: "Web3PromiseKit", package: "Web3"),
                .product(name: "Web3ContractABI", package: "Web3"),
                .product(name: "PromiseKit", package: "PromiseKit")
            ],resources: [
                .copy("Contracts/ABIRegistry.json"),
                .copy("Contracts/NetworksRegistry.json")
            ]
        ),
        .testTarget(
            name: "snet-sdk-swiftTests",
            dependencies: ["snet-sdk-swift"]),
    ],
    swiftLanguageVersions: [.v5]
)
