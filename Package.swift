// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    //.define("CRYPTO_IN_SWIFTPM"),
    // To develop this on Apple platforms, uncomment this define.
    .define("CRYPTO_IN_SWIFTPM_FORCE_BUILD_API"),
]

let package = Package(
    name: "ZenOPCUA",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "ZenOPCUA", targets: ["ZenOPCUA"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.23.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "1.1.2"),
//        .package(url: "https://github.com/IBM-Swift/BlueRSA.git", .branch("master"))
    ],
    targets: [
        .target(name: "ZenOPCUA", dependencies: [
            "NIO",
            "Crypto",
//            "CryptorRSA"
        ], swiftSettings: swiftSettings),
        .testTarget(name: "ZenOPCUATests", dependencies: ["ZenOPCUA"])
    ],
    swiftLanguageVersions: [.v5]
)
