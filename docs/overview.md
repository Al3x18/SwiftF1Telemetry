# SwiftF1Telemetry Overview

`SwiftF1Telemetry` is a pure Swift package for loading, parsing, caching, and processing Formula 1 telemetry data directly on device.

The project is inspired by the behavior of [FastF1](https://github.com/theOehrly/Fast-F1), but it is not a pandas-style port. Instead, it provides a Swift-native API built around typed models, async/await, disk caching, telemetry processing, and chart-ready outputs.

Current documented release: `0.2.1`

This page is the technical deep dive. For installation, quick start, and day-to-day usage snippets, use the repository [README](../README.md).

## Why This Package Exists

Many telemetry workflows today depend on Python tooling or server-side preprocessing. This package aims to provide a Swift-first alternative that can run:

- in iOS apps
- in macOS apps
- in Linux-oriented Swift tools
- in tests
- in command-line tools

The long-term goal is to make high-quality F1 telemetry analysis possible in Swift without requiring a Python runtime on the client.

## Features

- Pure Swift package
- Async/await API
- Strongly typed public models
- Real archive-backed session resolution
- Raw payload disk cache
- Configurable cache size profiles
- Fastest-lap lookup per driver
- Car data and position data parsing
- Merged telemetry traces
- Derived distance and relative distance channels
- Public lap-to-lap telemetry comparison APIs
- Delta-time and overlay chart helpers for two-lap analysis
- Plain chart-friendly output types
- CLI executable for manual inspection

## Requirements

- Swift 6.0+
- iOS 17+
- macOS 14+

The core package is also being prepared for non-Apple Swift toolchains, especially Linux and future Android-oriented Swift builds.

## Package Layout

```text
SwiftF1Telemetry/
├─ Package.swift
├─ README.md
├─ CHANGELOG.md
├─ CONTRIBUTING.md
├─ LICENSE
├─ docs/
│  ├─ overview.md
│  ├─ api.md
│  ├─ telemetry-data.md
│  └─ platform-support.md
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

## Example Output

For a real validated example:

```swift
let session = try await client.session(year: 2024, meeting: "Monza", session: .qualifying)
let lap = try await session.fastestLap(driver: "16")
let telemetry = try await session.telemetry(for: lap!)
```

For a comparison flow:

```swift
let comparison = try await session.compareFastestLaps(
    referenceDriver: "16",
    comparedDriver: "55"
)
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
- `TelemetryComparison`
- chart adapters

### Backend Layer

The backend resolves sessions and fetches raw datasets without leaking upstream details into the public API.

### Transport Layer

Networking is handled by `URLSession` with async/await and retry support.

### Cache Layer

Raw payloads are cached to disk using deterministic cache keys.

Cache filenames are generated with a cross-platform hashing implementation so the same cache-key logic can be reused outside Apple-only environments.

The public configuration supports multiple cache policies:

- `.disabled`: no size limit
- `.minimum`: up to `50 MB` and used by default
- `.medium`: up to `100 MB`
- `.large`: up to `200 MB`
- `.extraLarge`: up to `400 MB`

Consumers can clear all cached raw payloads through `F1Client.clearCache()`.

### Parsing Layer

Parsers convert raw archive payloads and compressed telemetry streams into typed Swift models.

### Processing Layer

Processing components:

- lap slicing
- telemetry merge
- interpolation stub
- distance calculation
- telemetry comparison alignment and delta calculation

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
- Linux support still needs broader automated validation
- Android support is still at the core-portability stage rather than app-integration stage

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
- strengthen comparison validation against FastF1-style reference plots on more sessions

Long-term priorities:

- API stabilization
- Linux CI coverage
- Android bridge layer
- Flutter plugin integration on top of native bridges
- richer comparison APIs beyond fastest-lap overlays
- SwiftUI sample integration
- broader telemetry processing utilities

## Contributing

Contributions are welcome, especially around:

- parser correctness
- FastF1 parity checks
- session edge cases
- documentation
- tests and fixtures

See also:

- [Contributing Guide](../CONTRIBUTING.md)
- [MIT License](../LICENSE)

If you contribute parser or lap-building logic derived from FastF1 behavior, please preserve attribution where appropriate.
