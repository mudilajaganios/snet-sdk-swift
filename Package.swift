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
        .binaryTarget(name: "snet_swift_pkg", path: "SNetContractsBinary/snet_swift_pkg.xcframework"),
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
