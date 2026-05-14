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
    targets: [
        .executableTarget(
            name: "CodexGauge",
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
