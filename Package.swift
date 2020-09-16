// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZenOPCUA",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "ZenOPCUA", targets: ["ZenOPCUA"]),
        .executable(name: "ZenOPCUA.bin", targets: ["ZenOPCUA.bin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .branch("master")),
//        .package(url: "https://github.com/apple/swift-crypto.git", .branch("master"))
//        .package(url: "https://github.com/IBM-Swift/BlueRSA.git", .branch("master"))
    ],
    targets: [
        .target(name: "ZenOPCUA", dependencies: [
            "NIO",
//            "CryptorRSA",
//            "Crypto"
        ]),
        .target(name: "ZenOPCUA.bin", dependencies: ["ZenOPCUA"]),
        .testTarget(name: "ZenOPCUATests", dependencies: ["ZenOPCUA"]),
    ],
    swiftLanguageVersions: [.v5]
)
