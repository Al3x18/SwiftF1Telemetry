# SwiftF1Telemetry API Reference

This document describes the current public API exposed by `SwiftF1Telemetry`.

For a more practical explanation of which telemetry fields are available for a lap and how to consume them, see [Telemetry Data Guide](telemetry-data.md).
For current Apple, Linux, and Android status, see [Platform Support](platform-support.md).

## Entry Point

### `F1Client`

`F1Client` is the main entry point for consumers of the library.

```swift
public final class F1Client: Sendable {
    public struct Configuration: Sendable {
        public var cacheDirectory: URL
        public var cacheMode: CacheMode
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
    public func clearCache() async throws
}
```

Responsibilities:

- Resolves a real archive session
- Creates the backend stack
- Loads session metadata
- Returns a `Session` handle for lap and telemetry access

What the caller should expect:

- `session(...)` is asynchronous and may perform real network and cache access
- it returns a fully usable `Session`
- it may throw `F1TelemetryError`
- `clearCache()` removes all cached raw payloads from the configured cache directory

### `F1Client.Configuration`

```swift
public struct Configuration: Sendable {
    public var cacheDirectory: URL
    public var cacheMode: CacheMode
    public var requestTimeout: TimeInterval
    public var maxRetries: Int
    public var userAgent: String

    public static let `default`: Configuration
}
```

```swift
public enum CacheMode: Sendable {
    case disabled
    case minimum
    case medium
    case large
    case extraLarge
}
```

What the caller should expect:

- `cacheDirectory` controls where raw upstream payloads are cached
- `cacheMode` controls the built-in cache size limit
- `requestTimeout` controls request timeout behavior
- `maxRetries` controls retry count in the HTTP layer
- `userAgent` customizes the HTTP user agent
- the default `userAgent` is `SwiftF1Telemetry/` plus `SwiftF1TelemetryVersion.current` (single source of truth for the release string)
- the default cache directory is selected using a portable strategy rather than an Apple-only path assumption

Cache modes:

- `.disabled`: caching stays enabled with no size limit
- `.minimum`: up to `50 MB` and used by default
- `.medium`: up to `100 MB`
- `.large`: up to `200 MB`
- `.extraLarge`: up to `400 MB`

## Session API

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

#### `laps()`

Returns:

- `[Lap]`

What the caller should expect:

- parsed laps for the session
- useful and already functional for the fastest-lap workflow
- not yet full FastF1 parity for every generated or edge-case lap

#### `fastestLap(driver:)`

Parameters:

- `driver`: racing number as `String`, for example `"16"`

Returns:

- `Lap?`

What the caller should expect:

- the fastest valid lap for that driver if one exists
- `nil` if no valid lap is available for that driver

#### `telemetry(for:)`

Parameters:

- `lap`: a `Lap` previously obtained from `Session`

Returns:

- `TelemetryTrace`

What the caller should expect:

- merged telemetry based on car data and position data
- per-sample `lapTime`, `sessionTime`, `distance`, and `relativeDistance`
- an error if telemetry for that lap cannot be built

## Session Metadata Models

### `SessionRef`

```swift
public struct SessionRef: Sendable, Hashable, Codable {
    public let year: Int
    public let meeting: String
    public let sessionType: SessionType
    public let backendIdentifier: String
    public let archivePath: String
}
```

What the caller should expect:

- a stable identity for the resolved session
- mostly useful for inspection/debugging rather than direct construction

### `SessionMetadata`

```swift
public struct SessionMetadata: Sendable, Hashable, Codable {
    public let officialName: String
    public let circuitName: String
    public let scheduledStart: Date?
    public let actualStart: Date?
    public let timezoneIdentifier: String?
}
```

What the caller should expect:

- official session naming and circuit naming
- scheduled and actual timing when available

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

What the caller should expect:

- raw values match the short codes commonly used in F1 tooling

## Lap Model

### `Lap`

```swift
public struct Lap: Sendable, Hashable, Codable {
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

What the caller should expect:

- time values are represented in seconds
- `startSessionTime` and `endSessionTime` are suitable for telemetry slicing
- `lapTime` and sector values may be `nil`

## Telemetry Models

### `TelemetryTrace`

```swift
public struct TelemetryTrace: Sendable, Codable {
    public let driverNumber: String
    public let lapNumber: Int
    public let samples: [TelemetrySample]
}
```

What the caller should expect:

- `samples` ordered on the telemetry timeline for that lap
- chart-helper methods available via extensions

### `TelemetrySample`

```swift
public struct TelemetrySample: Sendable, Hashable, Codable {
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

What the caller should expect:

- `sessionTime`: elapsed time on the session telemetry clock
- `lapTime`: elapsed time since the start of the selected lap
- telemetry channels are optional, because not every sample necessarily has every value
- `distance` is accumulated lap distance
- `relativeDistance` is normalized progress through the lap
- these public telemetry models support `Codable`, which makes future bridge layers easier to implement

### `SampleSource`

```swift
public enum SampleSource: String, Sendable, Codable {
    case car
    case position
    case merged
    case interpolated
}
```

What the caller should expect:

- a hint describing where the sample originated from

## Chart-Friendly API

### `ChartPoint`

```swift
public struct ChartPoint<Value: Sendable>: Sendable {
    public let x: Double
    public let y: Value
}
```

### `TrackPoint`

```swift
public struct TrackPoint: Sendable {
    public let x: Double
    public let y: Double
}
```

### `TelemetryTrace` helpers

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

What the caller should expect:

- arrays ready for charts
- no SwiftUI or UIKit dependency
- missing values are skipped automatically

## Errors

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

What the caller should expect:

- explicit typed failures
- useful dataset-specific parser failure context
- no requirement to unwrap generic `NSError` values

## Version Convenience API

### `SwiftF1TelemetryVersion`

```swift
public enum SwiftF1TelemetryVersion {
    public static let current = "0.1.1"
}
```

What the caller should expect:

- a convenience runtime string
- not the authoritative package version for SwiftPM resolution
- the authoritative package version is still the Git tag

## Recommended Usage Pattern

```swift
import SwiftF1Telemetry

let client = F1Client()
let session = try await client.session(year: 2024, meeting: "Monza", session: .qualifying)

guard let lap = try await session.fastestLap(driver: "16") else {
    return
}

let telemetry = try await session.telemetry(for: lap)
let speed = telemetry.speedSeriesByDistance()
let track = telemetry.trackMap()
```

This is the strongest supported path in the current implementation.
