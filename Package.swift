// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LinkwiseApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LinkwiseCore",
            targets: ["LinkwiseCore"]
        ),
        .executable(
            name: "LinkwiseApp",
            targets: ["LinkwiseApp"]
        )
    ],
    targets: [
        .target(
            name: "LinkwiseCore"
        ),
        .executableTarget(
            name: "LinkwiseApp",
            dependencies: ["LinkwiseCore"]
        ),
        .testTarget(
            name: "LinkwiseCoreTests",
            dependencies: ["LinkwiseCore"]
        )
    ]
)

