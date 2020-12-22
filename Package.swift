// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "DP3TSDK",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "DP3TSDK",
            targets: ["DP3TSDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/Swift-JWT.git", from: "3.6.1"),
        .package(url: "https://github.com/weichsel/ZIPFoundation/", .upToNextMajor(from: "0.9.0")),
    ],
    targets: [
        .target(
            name: "DP3TSDK",
            dependencies: ["SwiftJWT", "ZIPFoundation"]
        ),
        .testTarget(
            name: "DP3TSDKTests",
            dependencies: ["DP3TSDK"]
        ),
    ]
)
