// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "snet_sdk_swift",
    platforms: [.macOS(.v10_12),
                .iOS(.v11)],
    products: [
        .library(name: "snet-sdk-swift", type: .dynamic, targets: ["snet-sdk-swift", "snet-contracts"])
    ],
    dependencies: [
        .package(name: "Web3", url: "https://github.com/Boilertalk/Web3.swift.git", from: "0.5.0"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "snet-sdk-swift",
            dependencies: [
                .target(name: "snet-contracts"),
                .product(name: "Web3", package: "Web3"),
                .product(name: "Web3PromiseKit", package: "Web3"),
                .product(name: "Web3ContractABI", package: "Web3"),
                .product(name: "PromiseKit", package: "PromiseKit")
            ],
            path: "Sources/snet-sdk-swift"
        ),
        .target(name: "snet-contracts",
                path: "Sources/snet-contracts",
                resources: [
                    .copy("abi"),
                    .copy("networks")
                ]),
        .testTarget(
            name: "snet-sdk-swiftTests",
            dependencies: ["snet-sdk-swift"]),
    ],
    swiftLanguageVersions: [.v5]
)
