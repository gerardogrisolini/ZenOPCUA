// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
//        .package(url: "https://github.com/apple/swift-crypto.git", from: "1.1.2"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.2")
    ],
    targets: [
        .target(name: "ZenOPCUA", dependencies: [
            "NIO",
//            "Crypto"
            "CryptoSwift"
        ]),
        .testTarget(name: "ZenOPCUATests", dependencies: ["ZenOPCUA"])
    ],
    swiftLanguageVersions: [.v5]
)
