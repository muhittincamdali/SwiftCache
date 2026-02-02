// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCache",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "SwiftCache",
            targets: ["SwiftCache"]
        )
    ],
    targets: [
        .target(
            name: "SwiftCache",
            path: "Sources/SwiftCache",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "SwiftCacheTests",
            dependencies: ["SwiftCache"],
            path: "Tests/SwiftCacheTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
