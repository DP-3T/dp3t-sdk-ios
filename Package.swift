// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DP3TSDK",
    platforms: [
        // Add support for all platforms starting from a specific version.
        .iOS(.v10),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "DP3TSDK",
            targets: ["DP3TSDK"]
        ),
        .library(
            name: "DP3TSDK_CALIBRATION",
            targets: ["DP3TSDK_CALIBRATION"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.12.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "DP3TSDK",
            dependencies: ["SQLite", "SwiftProtobuf"]
        ),
        .target(
            name: "DP3TSDK_CALIBRATION",
            dependencies: ["SQLite", "SwiftProtobuf"],
            swiftSettings: [.define("CALIBRATION")]
        ),
        .testTarget(
            name: "DP3TSDKTests",
            dependencies: ["DP3TSDK"]
        ),
    ]
)
