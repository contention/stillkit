// swift-tools-version: 5.10
// Swift 5 language mode keeps strict-concurrency checks as warnings, not errors.

import PackageDescription

let package = Package(
    name: "StillKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "StillKit", targets: ["StillKit"])
    ],
    targets: [
        .target(
            name: "StillKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "StillKitTests",
            dependencies: ["StillKit"]
        ),
    ]
)
