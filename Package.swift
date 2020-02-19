// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZenOPCUA",
    products: [
        .library(name: "ZenOPCUA", targets: ["ZenOPCUA"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .branch("master"))
    ],
    targets: [
        .target(name: "ZenOPCUA",dependencies: ["NIO"]),
        .testTarget(name: "ZenOPCUATests", dependencies: ["ZenOPCUA"]),
    ]
)
