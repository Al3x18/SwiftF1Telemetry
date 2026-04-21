# API: Errors and Versioning

This section documents typed errors and version convenience APIs.

## When to read this page

- You are implementing robust error handling around API calls.
- You need to understand runtime version metadata vs SwiftPM tag versioning.

## Errors

### `F1TelemetryError`

The package exposes typed failures for:

- unavailable years, events, sessions, or drivers
- session resolution failures
- invalid responses
- network failures
- parser failures
- cache failures
- missing laps or telemetry
- internal invariant violations

```swift
public enum F1TelemetryError: Error, Sendable, Equatable {
    case yearNotAvailable(year: Int)
    case eventNotAvailable(year: Int, event: String)
    case sessionNotAvailable(year: Int, event: String, session: String)
    case driversNotAvailable(year: Int, event: String, session: String)
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

What the caller should expect:

- explicit typed failures
- useful dataset-specific parser failure context
- no requirement to unwrap generic `NSError` values
- `Equatable` conformance, so error cases can be compared in tests and app logic
- `LocalizedError` conformance with `errorDescription` for every case, so callers can display user-facing messages directly

Discovery-related cases:

- `yearNotAvailable(year:)` — the requested season year is not available through archive-backed discovery
- `eventNotAvailable(year:event:)` — the requested event could not be found for the selected season year
- `sessionNotAvailable(year:event:session:)` — the requested session is not available for the selected event and year
- `driversNotAvailable(year:event:session:)` — no drivers with lap-backed timing data are available for the selected session

## Version Convenience API

### `SwiftF1TelemetryVersion`

```swift
public enum SwiftF1TelemetryVersion {
    public static let current = "0.4.4"
}
```

What the caller should expect:

- a convenience runtime string
- not the authoritative package version for SwiftPM resolution
- the authoritative package version is still the Git tag
