// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Clasp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ClaspCore", targets: ["ClaspCore"]),
        .executable(name: "ClaspApp", targets: ["ClaspApp"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-testing.git",
            exact: "0.12.0"
        )
    ],
    targets: [
        .target(
            name: "ClaspCore"
        ),
        .executableTarget(
            name: "ClaspApp",
            dependencies: ["ClaspCore"]
        ),
        .testTarget(
            name: "ClaspCoreTests",
            dependencies: [
                "ClaspCore",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
