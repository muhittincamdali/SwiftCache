// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftCache",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SwiftCache", targets: ["SwiftCache"]),
    ],
    targets: [
        .target(
            name: "SwiftCache",
            path: "Sources/SwiftCache",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftCacheTests",
            dependencies: ["SwiftCache"]
        )
    ]
)
