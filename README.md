# SwiftF1Telemetry

`SwiftF1Telemetry` is a pure Swift package for loading, parsing, caching, and processing Formula 1 telemetry data directly on device.

The project is inspired by the behavior of [FastF1](https://github.com/theOehrly/Fast-F1), but it is not a pandas-style port. Instead, it provides a Swift-native API built around typed models, async/await, disk caching, telemetry processing, and chart-ready outputs.

Current documented release: `0.1.1`

## Documentation

- [Package Overview](docs/overview.md)
- [API Reference](docs/api.md)
- [Telemetry Data Guide](docs/telemetry-data.md)
- [Changelog](CHANGELOG.md)

## Status

`SwiftF1Telemetry` is currently in early development.

What already works well:

- Resolving real F1 archive sessions from year, meeting, and session type
- Loading official archive/livetiming datasets used by FastF1-style workflows
- Finding a driver's fastest lap
- Building lap telemetry for real sessions
- Exposing chart-ready speed, throttle, brake, gear, RPM, and track-map series
- Disk caching of raw upstream payloads
- Configurable cache sizing with built-in storage profiles
- Public cache clearing API
- Command-line smoke usage through `f1-cli`

What is still in progress:

- Full parity with FastF1's lap-building heuristics for every edge case
- Complete handling of generated laps, pit edge cases, and session interruptions
- More advanced interpolation and telemetry resampling behavior
- Broader validation across many seasons and session types

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<your-org>/SwiftF1Telemetry.git", from: "0.1.1")
]
```

Then add the product to your target:

```swift
dependencies: [
    .product(name: "SwiftF1Telemetry", package: "SwiftF1Telemetry")
]
```

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

You can also customize cache behavior:

```swift
var configuration = F1Client.Configuration.default
configuration.cacheMode = .medium

let client = F1Client(configuration: configuration)
```

For more details about supported APIs, runtime behavior, validation, architecture, and limitations, see:

- [docs/overview.md](docs/overview.md)
- [docs/api.md](docs/api.md)
- [docs/telemetry-data.md](docs/telemetry-data.md)

## Testing

Run the test suite with:

```bash
swift test
```

Run the CLI smoke test with:

```bash
swift run f1-cli 2024 Monza Q 16
```

## Versioning

This package follows the standard Swift Package Manager versioning model:

- use Semantic Versioning
- create Git tags such as `0.1.0`, `0.1.1`, `0.2.0`
- publish GitHub Releases from those tags
- treat the Git tag as the authoritative package version

Example dependency declaration:

```swift
.package(url: "https://github.com/<your-org>/SwiftF1Telemetry.git", from: "0.1.1")
```

`Package.swift` does not contain a version field, and that is correct for Swift packages.

The repository includes:

- `CHANGELOG.md` for release notes
- `SwiftF1TelemetryVersion.current` as a convenience runtime string
