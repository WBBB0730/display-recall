// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DisplayRecall",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DisplayRecallCore",
            targets: ["DisplayRecallCore"]
        ),
        .executable(
            name: "DisplayRecall",
            targets: ["DisplayRecall"]
        )
    ],
    targets: [
        .target(
            name: "DisplayRecallCore",
            resources: [
                .copy("Resources/Backends")
            ]
        ),
        .executableTarget(
            name: "DisplayRecall",
            dependencies: ["DisplayRecallCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DisplayRecallCoreTests",
            dependencies: ["DisplayRecallCore"]
        )
    ]
)
