// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftF1Telemetry",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftF1Telemetry",
            targets: ["SwiftF1Telemetry"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftF1Telemetry"
        ),
        .testTarget(
            name: "SwiftF1TelemetryTests",
            dependencies: ["SwiftF1Telemetry"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
