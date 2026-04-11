# SwiftF1Telemetry

`SwiftF1Telemetry` is a pure Swift package for loading, parsing, caching, and processing Formula 1 telemetry data directly on device.

The project is inspired by the behavior of [FastF1](https://github.com/theOehrly/Fast-F1), but it is not a pandas-style port. Instead, it provides a Swift-native API built around typed models, async/await, disk caching, telemetry processing, and chart-ready outputs.

Current documented release: `0.1.0`

## Status

`SwiftF1Telemetry` is currently in early development.

What already works well:

- Resolving real F1 archive sessions from year, meeting, and session type
- Loading official archive/livetiming datasets used by FastF1-style workflows
- Finding a driver's fastest lap
- Building lap telemetry for real sessions
- Exposing chart-ready speed, throttle, brake, gear, RPM, and track-map series
- Disk caching of raw upstream payloads
- Command-line smoke usage through `f1-cli`

What is still in progress:

- Full parity with FastF1's lap-building heuristics for every edge case
- Complete handling of generated laps, pit edge cases, and session interruptions
- More advanced interpolation and telemetry resampling behavior
- Broader validation across many seasons and session types

## Why This Package Exists

Many telemetry workflows today depend on Python tooling or server-side preprocessing. This package aims to provide a Swift-first alternative that can run:

- in iOS apps
- in macOS apps
- in tests
- in command-line tools

The long-term goal is to make high-quality F1 telemetry analysis possible in Swift without requiring a Python runtime on the client.

## Features

- Pure Swift package
- Async/await API
- Strongly typed public models
- Real archive-backed session resolution
- Raw payload disk cache
- Fastest-lap lookup per driver
- Car data and position data parsing
- Merged telemetry traces
- Derived distance and relative distance channels
- Plain chart-friendly output types
- CLI executable for manual inspection

## Requirements

- Swift 6.0+
- iOS 17+
- macOS 14+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<your-org>/SwiftF1Telemetry.git", from: "0.1.0")
]
```

Then add the product to your target:

```swift
dependencies: [
    .product(name: "SwiftF1Telemetry", package: "SwiftF1Telemetry")
]
```

## Package Layout

```text
SwiftF1Telemetry/
├─ Package.swift
├─ README.md
├─ CHANGELOG.md
├─ Sources/
│  ├─ SwiftF1Telemetry/
│  │  ├─ Public/
│  │  ├─ Models/
│  │  ├─ Backend/
│  │  ├─ Transport/
│  │  ├─ Cache/
│  │  ├─ Parsing/
│  │  ├─ Processing/
│  │  └─ Utils/
│  └─ F1CLI/
└─ Tests/
```

## Public API

### `F1Client`

`F1Client` is the main entry point for consumers of the library.

```swift
public final class F1Client: Sendable {
    public struct Configuration: Sendable {
        public var cacheDirectory: URL
        public var requestTimeout: TimeInterval
        public var maxRetries: Int
        public var userAgent: String

        public static let `default`: Configuration
    }

    public init(configuration: Configuration = .default)

    public func session(
        year: Int,
        meeting: String,
        session: SessionType
    ) async throws -> Session
}
```

Responsibilities:

- Resolves a real archive session
- Creates the backend stack
- Loads session metadata
- Returns a `Session` handle for lap and telemetry access

### `Session`

```swift
public struct Session: Sendable {
    public let ref: SessionRef
    public let metadata: SessionMetadata

    public func laps() async throws -> [Lap]
    public func fastestLap(driver: String) async throws -> Lap?
    public func telemetry(for lap: Lap) async throws -> TelemetryTrace
}
```

Responsibilities:

- Exposes the list of parsed laps
- Finds the fastest valid lap for a driver
- Builds a telemetry trace for a specific lap

### `Lap`

```swift
public struct Lap: Sendable, Hashable {
    public let driverNumber: String
    public let lapNumber: Int
    public let startSessionTime: TimeInterval
    public let endSessionTime: TimeInterval
    public let lapTime: TimeInterval?
    public let sector1: TimeInterval?
    public let sector2: TimeInterval?
    public let sector3: TimeInterval?
    public let isAccurate: Bool
}
```

This is the public representation of a single lap. All time values are expressed in seconds.

### `TelemetryTrace`

```swift
public struct TelemetryTrace: Sendable {
    public let driverNumber: String
    public let lapNumber: Int
    public let samples: [TelemetrySample]
}
```

### `TelemetrySample`

```swift
public struct TelemetrySample: Sendable, Hashable {
    public let sessionTime: TimeInterval
    public let lapTime: TimeInterval

    public let speed: Double?
    public let rpm: Double?
    public let throttle: Double?
    public let brake: Bool?
    public let drs: Int?
    public let gear: Int?

    public let x: Double?
    public let y: Double?
    public let z: Double?
    public let status: String?

    public let distance: Double?
    public let relativeDistance: Double?

    public let source: SampleSource
}
```

Each sample represents a merged telemetry point for the selected lap.

### `ChartPoint` and `TrackPoint`

```swift
public struct ChartPoint<Value: Sendable>: Sendable {
    public let x: Double
    public let y: Value
}

public struct TrackPoint: Sendable {
    public let x: Double
    public let y: Double
}
```

### `TelemetryTrace` chart helpers

```swift
public extension TelemetryTrace {
    func speedSeriesByDistance() -> [ChartPoint<Double>]
    func throttleSeriesByDistance() -> [ChartPoint<Double>]
    func brakeSeriesByDistance() -> [ChartPoint<Bool>]
    func gearSeriesByDistance() -> [ChartPoint<Int>]
    func rpmSeriesByDistance() -> [ChartPoint<Double>]
    func trackMap() -> [TrackPoint]
}
```

These helpers return plain Swift values and intentionally avoid UI framework coupling.

### `SessionType`

```swift
public enum SessionType: String, Sendable, Codable {
    case practice1 = "FP1"
    case practice2 = "FP2"
    case practice3 = "FP3"
    case sprintShootout = "SQ"
    case sprint = "S"
    case qualifying = "Q"
    case race = "R"
}
```

### `F1TelemetryError`

```swift
public enum F1TelemetryError: Error, Sendable {
    case sessionNotFound(year: Int, meeting: String, session: String)
    case invalidResponse(description: String)
    case networkFailure(description: String)
    case parseFailure(dataset: String, description: String)
    case cacheFailure(description: String)
    case noLapsAvailable(driver: String)
    case telemetryUnavailable(driver: String, lap: Int)
    case internalInvariantViolation(description: String)
}
```

### `SwiftF1TelemetryVersion`

```swift
public enum SwiftF1TelemetryVersion {
    public static let current = "0.1.0"
}
```

This gives consumers a runtime-accessible library version string. The authoritative package version for Swift Package Manager is still the Git tag.

## Quick Start

```swift
import SwiftF1Telemetry

let client = F1Client()

let session = try await client.session(
    year: 2024,
    meeting: "Monza",
    session: .qualifying
)

guard let lap = try await session.fastestLap(driver: "16") else {
    return
}

let telemetry = try await session.telemetry(for: lap)

print("Lap:", lap.lapNumber)
print("Lap time:", lap.lapTime ?? 0)
print("Samples:", telemetry.samples.count)
print("Speed series points:", telemetry.speedSeriesByDistance().count)
```

## Example Output

For a real validated example:

```swift
let session = try await client.session(year: 2024, meeting: "Monza", session: .qualifying)
let lap = try await session.fastestLap(driver: "16")
let telemetry = try await session.telemetry(for: lap!)
```

At the time of validation, this resolved to:

- Driver: `16`
- Session: `2024 Monza Qualifying`
- Fastest lap: `Lap 20`
- Lap time: `1:19.461`
- Telemetry sample count: `314`

These values were compared directly against FastF1 and matched on the same real session for lap number, lap time, sample count, and speed endpoints.

## CLI Usage

The package includes a small executable target:

```bash
swift run f1-cli 2024 Monza Q 16
```

Argument format:

```text
swift run f1-cli <year> <meeting> <session> [driver]
```

Examples:

```bash
swift run f1-cli 2024 Monza Q 16
swift run f1-cli 2024 Silverstone R 44
swift run f1-cli 2024 Monaco FP1 1
```

## Data Sources

The current implementation uses the official F1 archive/livetiming datasets that FastF1-style workflows are built on, including:

- `Index.json`
- `SessionInfo.jsonStream`
- `SessionData.json`
- `TimingData.jsonStream`
- `TimingAppData.jsonStream`
- `Heartbeat.jsonStream`
- `CarData.z.jsonStream`
- `Position.z.jsonStream`

## Architecture Overview

### Public Layer

This is the API consumed by apps and tools:

- `F1Client`
- `Session`
- `Lap`
- `TelemetryTrace`
- chart adapters

### Backend Layer

The backend resolves sessions and fetches raw datasets without leaking upstream details into the public API.

### Transport Layer

Networking is handled by `URLSession` with async/await and retry support.

### Cache Layer

Raw payloads are cached to disk using deterministic cache keys.

### Parsing Layer

Parsers convert raw archive payloads and compressed telemetry streams into typed Swift models.

### Processing Layer

Processing components:

- lap slicing
- telemetry merge
- interpolation stub
- distance calculation
- delta calculation foundation

## Accuracy and Validation

The library has already been compared against FastF1 on a real session:

- `2024 Italian Grand Prix`
- `Qualifying`
- Driver `16`

Aligned results:

- fastest lap number
- fastest lap time
- car telemetry sample count
- first and last speed values

## Current Limitations

This package is not yet a full replacement for FastF1 in all scenarios.

Known gaps include:

- total lap table completeness is still behind FastF1 in some sessions
- generated/incomplete laps are not yet reconstructed as thoroughly
- pit in/out and session interruption handling is still simpler than FastF1
- interpolation behavior is currently minimal
- some edge-case laps may still differ from FastF1 outside the validated path

## Testing

Run the test suite with:

```bash
swift test
```

Run the CLI with:

```bash
swift run f1-cli 2024 Monza Q 16
```

## Versioning

This package should be versioned the standard Swift Package Manager way:

- use Semantic Versioning
- create Git tags such as `0.1.0`, `0.1.1`, `0.2.0`
- publish GitHub Releases from those tags
- treat the Git tag as the authoritative package version

Example dependency declaration:

```swift
.package(url: "https://github.com/<your-org>/SwiftF1Telemetry.git", from: "0.1.0")
```

The repository includes:

- `CHANGELOG.md` for release notes
- `SwiftF1TelemetryVersion.current` as a convenience runtime string

- `0.1.0`: first public preview with real archive-backed telemetry and validated fastest-lap flow

## Legal Notes

FastF1 is an important behavioral reference for this project and should be credited appropriately when relevant.

This package does not bundle FastF1 and does not expose a pandas-like API.

Please also review the terms and operational constraints of the upstream F1 data sources before using this package in production environments.

## Roadmap

Short-term priorities:

- improve lap table parity with FastF1
- port more lap-building heuristics
- improve interpolation and merge fidelity
- expand validation across multiple weekends and session types
- improve README examples and add more tests

Long-term priorities:

- API stabilization
- richer comparison APIs
- SwiftUI sample integration
- broader telemetry processing utilities

## Contributing

Contributions are welcome, especially around:

- parser correctness
- FastF1 parity checks
- session edge cases
- documentation
- tests and fixtures

If you contribute parser or lap-building logic derived from FastF1 behavior, please preserve attribution where appropriate.
