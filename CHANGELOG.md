# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- platform support documentation covering Apple, Linux, Android, and future Flutter integration
- portable default cache-directory selection for non-Apple environments
- `f1-cli` `clear-cache` / `--clear-cache` subcommand that calls `F1Client.clearCache()`

### Changed

- replaced `CryptoKit` with cross-platform `swift-crypto` for deterministic cache-key hashing
- made public session and telemetry models easier to bridge by adding `Codable` conformance
- clarified the repository direction toward a portable Swift core with future Android bridge layers

### Tested

- added codable round-trip coverage for public session and telemetry models

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
