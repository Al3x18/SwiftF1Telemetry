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
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .systemLibrary(
            name: "CZlib",
            pkgConfig: "zlib",
            providers: [
                .brew(["zlib"]),
                .apt(["zlib1g-dev"]),
            ]
        ),
        .target(
            name: "SwiftF1Telemetry",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                "CZlib",
            ]
        ),
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
