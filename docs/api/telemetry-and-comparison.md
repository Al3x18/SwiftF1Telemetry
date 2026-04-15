# API: Telemetry and Comparison

This section documents telemetry models, comparison models, and chart-friendly helper APIs.

## When to read this page

- You are extracting telemetry traces or comparing two laps.
- You need chart helper APIs and semantics for delta/alignment outputs.

## Telemetry APIs on `Session`

### `telemetry(for:)`

Parameters:

- `lap`: a `Lap` previously obtained from `Session`

Returns:

- `TelemetryTrace`

What the caller should expect:

- merged telemetry based on car data and position data
- per-sample `lapTime`, `sessionTime`, `distance`, and `relativeDistance`
- an error if telemetry for that lap cannot be built

### `compare(reference:compared:)`

Returns:

- `TelemetryComparison`

What the caller should expect:

- aligns two already built telemetry traces on shared lap progress
- calculates point-by-point delta time as `compared - reference`
- suitable when you already manage lap selection and telemetry loading yourself

### `compareTelemetry(referenceLap:comparedLap:)`

Returns:

- `TelemetryComparison`

What the caller should expect:

- convenience API that builds telemetry for two selected laps and compares them
- useful for comparing arbitrary laps from the same session

### `compareFastestLaps(referenceDriver:comparedDriver:)`

Parameters:

- `referenceDriver`: racing number, last name, abbreviation, or full name
- `comparedDriver`: racing number, last name, abbreviation, or full name

Returns:

- `TelemetryComparison`

What the caller should expect:

- the highest-level comparison API currently provided by the library
- automatically resolves the fastest valid lap for each driver
- accepts name-based identifiers like `"Leclerc"` or `"LEC"` in addition to driver numbers
- builds both telemetry traces and returns an aligned comparison result
- throws `noLapsAvailable` if either driver has no valid fastest lap

## Telemetry Models

### `TelemetryTrace`

```swift
public struct TelemetryTrace: Sendable, Codable {
    public let driverNumber: String
    public let lapNumber: Int
    public let samples: [TelemetrySample]
    public let officialLapTime: TimeInterval?
}
```

What the caller should expect:

- `samples` ordered on the telemetry timeline for that lap
- `officialLapTime` carries the timing-feed lap time used to anchor boundary normalization in comparisons
- chart-helper methods available via extensions
- suitable as input to lap comparison APIs

### `TelemetrySample`

```swift
public struct TelemetrySample: Sendable, Hashable, Codable {
    public var sessionTime: TimeInterval
    public var lapTime: TimeInterval

    public var speed: Double?
    public var rpm: Double?
    public var throttle: Double?
    public var brake: Bool?
    public var drs: Int?
    public var gear: Int?

    public var x: Double?
    public var y: Double?
    public var z: Double?
    public var status: String?

    public var distance: Double?
    public var relativeDistance: Double?

    public var source: SampleSource
}
```

What the caller should expect:

- `sessionTime`: elapsed time on the session telemetry clock
- `lapTime`: elapsed time since the start of the selected lap
- telemetry channels are optional, because not every sample necessarily has every value
- `distance` is accumulated lap distance
- `relativeDistance` is normalized progress through the lap, computed from physical distance rather than sample index
- properties are declared as `var` for idiomatic struct copy-and-mutate; `Sendable`, `Hashable`, and `Codable` conformance is unaffected
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

## Comparison Models

### `TelemetryComparison`

```swift
public struct TelemetryComparison: Sendable, Codable {
    public let reference: TelemetryTrace
    public let compared: TelemetryTrace
    public let samples: [TelemetryComparisonSample]

    public var finalDelta: TimeInterval? { get }
}
```

What the caller should expect:

- a full comparison object containing both source traces plus aligned samples
- `reference` is the baseline lap
- `compared` is the lap measured against it
- `finalDelta` is the end-of-lap gap using `compared - reference`

### `TelemetryComparisonSample`

```swift
public struct TelemetryComparisonSample: Sendable, Hashable, Codable {
    public let distance: Double?
    public let relativeDistance: Double
    public let referenceLapTime: TimeInterval
    public let comparedLapTime: TimeInterval
    public let delta: TimeInterval

    public let referenceSpeed: Double?
    public let referenceRPM: Double?
    public let referenceThrottle: Double?
    public let referenceBrake: Bool?
    public let referenceDRS: Int?
    public let referenceGear: Int?

    public let comparedSpeed: Double?
    public let comparedRPM: Double?
    public let comparedThrottle: Double?
    public let comparedBrake: Bool?
    public let comparedDRS: Int?
    public let comparedGear: Int?
}
```

What the caller should expect:

- one aligned progress point per sample
- both laps' telemetry values available in the same sample
- enough information to build custom overlay charts or export a comparison dataset

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

### `TelemetryComparison` helpers

```swift
public extension TelemetryComparison {
    func deltaSeriesByDistance() -> [ChartPoint<Double>]
    func deltaSeriesByRelativeDistance() -> [ChartPoint<Double>]
    func referenceSpeedSeriesByDistance() -> [ChartPoint<Double>]
    func comparedSpeedSeriesByDistance() -> [ChartPoint<Double>]
    func referenceThrottleSeriesByDistance() -> [ChartPoint<Double>]
    func comparedThrottleSeriesByDistance() -> [ChartPoint<Double>]
    func referenceRPMSeriesByDistance() -> [ChartPoint<Double>]
    func comparedRPMSeriesByDistance() -> [ChartPoint<Double>]
    func referenceGearSeriesByDistance() -> [ChartPoint<Int>]
    func comparedGearSeriesByDistance() -> [ChartPoint<Int>]
    func referenceBrakeSeriesByDistance() -> [ChartPoint<Bool>]
    func comparedBrakeSeriesByDistance() -> [ChartPoint<Bool>]
}
```

What the caller should expect:

- chart-ready overlay output for the most common comparison channels
- direct delta plotting without reprocessing raw comparison samples
- a clean base for FastF1-style two-driver visualizations
