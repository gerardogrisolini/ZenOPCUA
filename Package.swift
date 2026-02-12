// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZenOPCUA",
    platforms: [
        .macOS(.v10_15),
		.iOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "ZenOPCUA", targets: ["ZenOPCUA"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.94.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "ZenOPCUA",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "X509", package: "swift-certificates")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        ),
        .testTarget(
            name: "ZenOPCUATests",
            dependencies: ["ZenOPCUA"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
