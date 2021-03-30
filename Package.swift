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
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "snet-sdk-swift",
            targets: ["snet-sdk-swift"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "Web3", url: "https://github.com/Boilertalk/Web3.swift.git", from: "0.5.0"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "snet-sdk-swift",
            dependencies: [
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
