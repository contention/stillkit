// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "still-setup",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "still-setup", targets: ["still-setup"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.27.0"),
    ],
    targets: [
        .executableTarget(
            name: "still-setup",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
            ]
        ),
    ]
)
