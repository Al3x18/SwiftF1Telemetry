# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.4.2] - YYYY-MM-DD

### Changed

- `F1Client.Configuration.CacheMode` now exposes:
  - `.unlimited` to keep caching enabled with no size cap
  - `.noCache` to fully bypass cache reads and writes
- cache semantics were clarified and aligned in code:
  - `.noCache` now reports `maxSizeInBytes = 0`
  - `.unlimited` now reports `maxSizeInBytes = nil`
- backend caching flow now short-circuits when `.noCache` is selected, fetching directly without touching the cache store
- cache protocol file renamed from `CacheStore.swift` to `CacheStoreProtocol.swift` for clearer intent
- cache/docs references updated to match the new cache mode names and behavior

### Tested

- added cache-mode regression tests for:
  - `.noCache` bypass behavior (no cache read/write calls)
  - `.noCache` zero-byte limit semantics
  - `.unlimited` no-limit semantics
  - bounded-mode size mappings and zero-limit eviction behavior
- full package test suite passes

## [0.4.1] - 2026-04-16

### Changed

- improved session metadata resilience for historical sessions:
  - `SessionData.json` is now optional when building metadata envelopes
  - session-start resolution now falls back to `scheduledStart` when `actualStart` is unavailable
- hardened event discovery matching to avoid false positives from short queries (e.g. `"Spa"` no longer resolving to `"España"` due to broad token-prefix matching)
- optimized name-based driver resolution in `Session`:
  - internal driver-list loading is now reused across multi-driver flows
  - `compareFastestLaps(referenceDriver:comparedDriver:)` resolves both identifiers from one shared driver index instead of loading/parsing twice
- expanded regression coverage with dedicated meeting-matching tests:
  - `spaQueryMatchesBelgianGrandPrixInsteadOfSpanishGrandPrix`
  - `barcelonaQueryMatchesSpanishGrandPrixByLocation`
  - `monzaQueryMatchesItalianGrandPrixByCircuitName`
  - new `struct MeetingMatcher` in a separate file used to avoid error in event matching (e.g. "spa" matching "españa")
- refocused `README.md` as the package landing page while keeping repository documentation centered in `docs/`
- configured Swift Package Index external documentation through `.spi.yml`
- reorganized repository documentation so `docs/overview.md` acts as the GitHub- and SPI-friendly entry point
- `SwiftF1TelemetryVersion.current` updated to `0.4.1`

## [0.4.0] - 2026-04-15

### Added

- public discovery APIs on `F1Client`:
  - `availableYears()`
  - `availableEvents(in:)`
  - `availableSessions(in:event:)`
  - `availableDrivers(in:event:session:)`
- public discovery models:
  - `EventDescriptor`
  - `SessionDescriptor`
  - `DriverDescriptor`
- CLI discovery flow:
  - `swift run f1-cli discover`
  - `swift run f1-cli discover <year>`
  - `swift run f1-cli discover <year> <event>`
  - `swift run f1-cli discover <year> <event> <session>`
- driver-list parsing from archive `DriverList.jsonStream` to enrich discovery output
- public `Session.resolveDriverNumber(_:)` for resolving driver identifiers (number, surname, abbreviation, full name)
- test coverage for the new discovery APIs

### Changed

- archive session decoding is now more tolerant of incomplete official index entries with missing `Name`, `Key`, or `Path`
- only archive sessions that the library can actually open are surfaced in discovery
- discovery APIs now throw typed public errors for unavailable years, events, sessions, and drivers
- `f1-cli discover` now renders these failures as user-facing messages instead of raw enum dumps or HTTP details
- `DriverDescriptor` now includes optional driver profile fields:
  - `firstName`
  - `lastName`
  - `fullName`
  - `abbreviation`
  - `broadcastName`
  - `teamName`
  - `teamColour`
  - `countryCode`
- `F1Client.availableDrivers(in:event:session:)` now returns enriched driver descriptors when the driver list feed is available
- `Session.fastestLap(driver:)` and `Session.compareFastestLaps(referenceDriver:comparedDriver:)` now accept name-based driver identifiers in addition to racing numbers
- `f1-cli` telemetry and compare flows now accept driver numbers, abbreviations, and surnames; discovery output now prints enriched driver details when available
- expanded tests for discovery models, driver-list parsing integration, and name-based driver resolution
- README, overview, and API docs now document the discovery flow
- `SwiftF1TelemetryVersion.current` updated to `0.4.0`

## [0.3.2] - 2026-04-15

### Changed

- `resolveSession` now caches the season index (`Index.json`) for past years, repeated session resolution for completed seasons no longer requires a network request
- Current and future season indices are always fetched from the network to avoid stale data when new meetings are added mid-season
- `SwiftF1TelemetryVersion.current` updated to `0.3.2`

## [0.3.1] - 2026-04-15

### Added

- `F1Client.cacheSizeInMB()` returns the current on-disk cache size in megabytes
- `CacheStore.totalSizeInBytes()` protocol requirement backing the public cache-size API

### Changed

- Backend fetch functions (`fetchSessionMetadata`, `fetchTimingData`, `fetchCarData`, `fetchPositionData`) now use `async let` for parallel HTTP requests on cold cache, reducing total fetch time to the single slowest request instead of the sum of all requests
- `Session.compareFastestLaps(referenceDriver:comparedDriver:)` now fetches lap data and telemetry data concurrently via `async let`
- `SwiftF1TelemetryVersion.current` updated to `0.3.1`

## [0.3.0] - 2026-04-14

### Fixed

- `TelemetryComparison.finalDelta` now matches the official lap-time gap instead of drifting due to telemetry clock misalignment
- `DistanceCalculator` computes `relativeDistance` from physical distance (`distance / totalDistance`) instead of array index ratio — two traces with different sample counts now align at the same track position
- `TelemetryComparisonCalculator` normalizes each trace's `lapTime` values to the official `Lap.lapTime` at boundaries, ensuring `finalDelta` and the full delta curve converge to the real timing gap

### Added

- `TelemetryTrace.officialLapTime` property carries the official lap time from the timing feed through the processing pipeline
- 8 new comparison and distance-calculator tests covering the Monza bug scenario, asymmetric sample counts, boundary normalization, backward compatibility, and full-pipeline end-to-end validation

### Changed

- `TelemetrySample` stored properties changed from `let` to `var` for idiomatic struct copy-and-mutate — `Sendable`, `Hashable`, and `Codable` conformance unchanged
- removed `Interpolator` from the processing pipeline, it was a stub that only duplicated a sort already performed by `TelemetryMerger` and `DistanceCalculator`
- `Session.telemetry(for:)` now passes `lap.lapTime` as `officialLapTime` into the resulting `TelemetryTrace`
- `SwiftF1TelemetryVersion.current` updated to `0.3.0`

### Removed

- `Interpolator` struct and its `interpolate(samples:)` method (no-op stub)

## [0.2.1] - 2026-04-14

### Added

- CLI comparison mode: pass a second driver number to compare fastest laps (e.g. `swift run f1-cli 2024 "Monza" Q 16 55`)
- comprehensive Swift Documentation Markup with usage examples on all public APIs: `F1Client`, `Session`, `Lap`, `TelemetryTrace`, `TelemetrySample`, `SampleSource`, `TelemetryComparison`, `TelemetryComparisonSample`, `ChartPoint`, `TrackPoint`, `SessionType`, `SessionRef`, `SessionMetadata`, `F1TelemetryError`, `TimeUtils`, and `SwiftF1TelemetryVersion`
- doc comments with `- Parameter` / `- Parameters` markup on all public initializers and methods
- every chart helper on `TelemetryTrace` and `TelemetryComparison` now has a one-line doc comment

### Changed

- `SwiftF1TelemetryVersion.current` updated to `0.2.1`
- `F1Client.Configuration.CacheMode.disabled` doc comment corrected (was misleadingly saying "keeps caching enabled")
- CLI usage string updated to show the optional compare-driver argument

## [0.2.0] - 2026-04-14

### Added

- public `TelemetryComparison` and `TelemetryComparisonSample` models for aligned lap-to-lap analysis
- public `Session.compare(reference:compared:)` API for comparing two already-built telemetry traces
- public `Session.compareTelemetry(referenceLap:comparedLap:)` API for comparing two selected laps
- public `Session.compareFastestLaps(referenceDriver:comparedDriver:)` API for comparing the fastest valid laps of two drivers
- chart-ready comparison helpers for delta, speed, throttle, RPM, gear, and brake overlays
- dedicated tests for interpolation, delta calculation, and the public fastest-lap comparison flow

### Changed

- `SwiftF1TelemetryVersion.current` updated to `0.2.0`
- README and docs now describe lap comparison workflows and outputs more clearly
- API reference and telemetry guide now document the comparison models and helper series in detail

## [0.1.3] - 2026-04-12

### Added

- merge of `multiplatform-porting` into `main`: portable cache paths, crypto, Codable public models, and CLI cache control
- `PlatformPaths` helper for default on-disk cache directory across supported platforms
- `swift-crypto` dependency (via `Package.resolved`) replacing `CryptoKit` usage in cache key hashing
- `docs/platform-support.md` and related platform roadmap documentation (Apple, Linux, Android, future Kotlin/Flutter)
- `f1-cli` `clear-cache` / `--clear-cache` subcommand calling `F1Client.clearCache()`
- `Codable` conformance on public session, lap, telemetry, and chart adapter types for bridging and serialization
- tests exercising Codable round-trips for public models

### Changed

- `CacheKey` hashing now uses `swift-crypto` for cross-platform deterministic filenames
- default `F1Client.Configuration` cache directory resolved through `PlatformPaths`
- `SwiftF1TelemetryVersion.current` updated to `0.1.3`; README, overview, and API docs list `0.1.3` as the current release
- repository direction documentation updated toward a portable Swift core

## [0.1.2] - 2026-04-12

### Changed

- default HTTP `userAgent` in `F1Client.Configuration` is `SwiftF1Telemetry/` plus `SwiftF1TelemetryVersion.current` (single source of truth instead of a duplicated version literal)
- `docs/api.md` documents the default `userAgent` behavior and its relationship to `SwiftF1TelemetryVersion`

## [0.1.1] - 2026-04-12

### Added

- Public `F1Client.Configuration.CacheMode` with built-in cache size profiles
- Public `F1Client.clearCache()` API for deleting all cached raw payloads
- Dedicated telemetry consumer guide in `docs/telemetry-data.md`
- Inline Quick Help documentation for the public client, session, and telemetry APIs

### Changed

- Default cache policy is now `.minimum`, which keeps up to `50 MB` of cached data
- Documentation is now split across `docs/overview.md`, `docs/api.md`, and `docs/telemetry-data.md`
- API docs now describe cache configuration and cache clearing behavior
- Runtime version string was updated to `0.1.1`

### Tested

- Added coverage for cache size policy behavior
- Added coverage for clearing the cache through the public client API
- Full test suite passes with the updated API and documentation

## [0.1.0] - 2026-04-11

### Added

- Initial Swift Package structure for `SwiftF1Telemetry`
- Public API centered around `F1Client`, `Session`, `Lap`, and `TelemetryTrace`
- Archive-backed session resolution using official F1 archive/livetiming data
- Parsing for `TimingData`, `TimingAppData`, `SessionInfo`, `SessionData`, `CarData.z`, and `Position.z`
- Real disk cache for raw upstream payloads
- Basic telemetry merge pipeline
- Distance and relative-distance calculation
- Chart-ready helper APIs
- `f1-cli` executable target
- Initial test suite

### Validated

- Fastest-lap flow against a real reference session
- Telemetry alignment against FastF1 for:
  - fastest lap number
  - lap time
  - telemetry sample count
  - first and last speed values
  - near-aligned lap distance

### Known Limitations

- Lap table completeness is not yet at full FastF1 parity
- Generated laps, pit edge cases, and interruption heuristics still need expansion
- Interpolation behavior is still intentionally minimal
