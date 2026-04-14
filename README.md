<p align="center">
  <img src="assets/SwiftF1Icon.png" width="134" alt="SwiftF1Telemetry icon" /><br>
  <b style="font-size:3em;"><u>SwiftF1Telemetry</u></b>
</p>

`SwiftF1Telemetry` is a pure Swift package for loading, parsing, caching, and processing Formula 1 telemetry data directly on device.

The project is inspired by the behavior of [FastF1](https://github.com/theOehrly/Fast-F1), but it is not a pandas-style port. Instead, it provides a Swift-native API built around typed models, async/await, disk caching, telemetry processing, and chart-ready outputs.

Current documented release: `0.3.2`

## Documentation

- [Package Overview](docs/overview.md)
- [API Reference](docs/api.md)
- [Telemetry Data Guide](docs/telemetry-data.md)
- [Platform Support](docs/platform-support.md)
- [Contributing Guide](CONTRIBUTING.md)
- [License](LICENSE)
- [Changelog](CHANGELOG.md)

## Status

`SwiftF1Telemetry` is currently in early development.

Implemented:

- Real session resolution from archive data
- Fastest-lap lookup and telemetry extraction
- Two-lap / two-driver fastest-lap telemetry comparison
- Chart-ready telemetry and comparison series
- Disk caching with configurable storage profiles
- Public Codable models and CLI smoke usage (`f1-cli`)

In progress:

- Additional FastF1 parity for edge-case lap reconstruction
- Broader cross-season and cross-session validation
- Linux CI/runtime hardening and Android bridge work

For full feature coverage, architecture, data sources, validation notes, and limitations, see [docs/overview.md](docs/overview.md).

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Al3x18/SwiftF1Telemetry.git", from: "0.3.2")
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

You can also compare two drivers directly:

```swift
let comparison = try await session.compareFastestLaps(
    referenceDriver: "16",
    comparedDriver: "55"
)

print("Final delta:", comparison.finalDelta ?? 0)
print("Delta points:", comparison.deltaSeriesByDistance().count)
print("Reference speed points:", comparison.referenceSpeedSeriesByDistance().count)
print("Compared speed points:", comparison.comparedSpeedSeriesByDistance().count)
```

For complete technical documentation, see:

- [docs/overview.md](docs/overview.md)
- [docs/api.md](docs/api.md)
- [docs/telemetry-data.md](docs/telemetry-data.md)
- [docs/platform-support.md](docs/platform-support.md)

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
- create Git tags such as `0.1.0`, `0.2.0`, `0.3.2`
- publish GitHub Releases from those tags
- treat the Git tag as the authoritative package version

Example dependency declaration:

```swift
.package(url: "https://github.com/Al3x18/SwiftF1Telemetry.git", from: "0.3.2")
```

`Package.swift` does not contain a version field, and that is correct for Swift packages.

The repository includes:

- `CHANGELOG.md` for release notes
- `CONTRIBUTING.md` for contribution guidelines
- `LICENSE` with the MIT license text
- `SwiftF1TelemetryVersion.current` as a convenience runtime string

## Project Scope And Roadmap

Detailed scope, known gaps, and roadmap are maintained in [docs/overview.md](docs/overview.md) to keep this README focused on installation and usage.
