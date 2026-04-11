# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

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
