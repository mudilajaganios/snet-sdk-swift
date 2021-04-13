// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "snet_sdk_swift",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12)
    ],
    products: [
//        .library(name: "snet-contracts", type: .dynamic, targets: ["snet-contracts"]),
        .library(name: "snet-sdk-swift", type: .dynamic, targets: ["snet-sdk-swift", "snet-contracts"])
    ],
    dependencies: [
        .package(name: "Web3", url: "https://github.com/Boilertalk/Web3.swift.git", from: "0.5.0"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.0.0")
    ],
    targets: [
//        .binaryTarget(name: "snet_contracts",
//                      url: "https://github.com/singnet/snet-sdk-swift/releases/download/0.0.2/snet_contracts.0.0.3.zip",
//                      checksum: "9b7ac7028d431802dc0e4325bb94ea250c9bb1b50d89e4f440f96aadbe711519"),
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
