// swift-tools-version: 5.10
// Swift 5 language mode keeps strict-concurrency checks as warnings, not errors.

import PackageDescription

let package = Package(
    name: "StillKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "StillKit", targets: ["StillKit"])
    ],
    targets: [
        .target(name: "StillKit")
    ]
)
