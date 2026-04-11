// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftF1Telemetry",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SwiftF1Telemetry", targets: ["SwiftF1Telemetry"]),
        .executable(name: "f1-cli", targets: ["F1CLI"]),
    ],
    targets: [
        .target(name: "SwiftF1Telemetry"),
        .executableTarget(
            name: "F1CLI",
            dependencies: ["SwiftF1Telemetry"]
        ),
        .testTarget(
            name: "SwiftF1TelemetryTests",
            dependencies: ["SwiftF1Telemetry"]
        ),
    ]
)
