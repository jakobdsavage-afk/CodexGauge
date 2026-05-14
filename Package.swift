// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexGauge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexGauge", targets: ["CodexGauge"]),
        .executable(name: "CodexGaugeProbe", targets: ["CodexGaugeProbe"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", .upToNextMajor(from: "2.9.1"))
    ],
    targets: [
        .executableTarget(
            name: "CodexGauge",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "CodexGauge",
            exclude: [
                "Resources/Info.plist"
            ]
        ),
        .executableTarget(
            name: "CodexGaugeProbe",
            dependencies: [],
            path: "Tools/CodexGaugeProbe"
        )
    ]
)
