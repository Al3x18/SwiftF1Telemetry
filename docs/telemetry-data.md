# Telemetry Data Guide

This document explains which telemetry data is currently available for a lap, how to extract it, and what users should expect when working with it.

## When to read this page

- You are building charts, overlays, or telemetry analysis views.
- You need channel-level expectations, optional fields, and comparison semantics.

## Typical Flow

The standard extraction flow is:

```swift
import SwiftF1Telemetry

let client = F1Client()
let session = try await client.session(year: 2024, meeting: "Monza", session: .qualifying)

guard let lap = try await session.fastestLap(driver: "16") else {
    return
}

let telemetry = try await session.telemetry(for: lap)
```

After this, all telemetry information is available from:

- `telemetry.samples`
- chart helpers on `TelemetryTrace`

If you want to compare two laps, the standard flow is:

```swift
let comparison = try await session.compareFastestLaps(
    referenceDriver: "16",
    comparedDriver: "55"
)
```

After this, comparison data is available from:

- `comparison.samples`
- chart helpers on `TelemetryComparison`

## What a `TelemetryTrace` Contains

`TelemetryTrace` contains:

```swift
public struct TelemetryTrace: Sendable {
    public let driverNumber: String
    public let lapNumber: Int
    public let samples: [TelemetrySample]
    public let officialLapTime: TimeInterval?
}
```

Each `TelemetrySample` may contain:

```swift
public struct TelemetrySample: Sendable, Hashable {
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

## Available Channels

### Time Channels

- `sessionTime`
  - elapsed time on the session telemetry clock
- `lapTime`
  - elapsed time since the start of the selected lap

What to expect:

- both are expressed in seconds
- `lapTime` is usually the most convenient x-axis for lap-local analysis
- `distance` is usually the most convenient x-axis for chart overlays

### Car Channels

- `speed`
  - km/h
- `rpm`
  - engine RPM
- `throttle`
  - normalized throttle value from upstream telemetry
- `brake`
  - boolean brake state
- `drs`
  - raw DRS state code
- `gear`
  - integer gear number

What to expect:

- `speed`, `rpm`, `throttle` are continuous-style signals
- `brake`, `gear`, and `drs` behave like discrete signals
- not every consumer should interpolate these channels the same way

### Position Channels

- `x`
- `y`
- `z`
- `status`

What to expect:

- coordinates are track-position values from official position data
- position coordinates are handled using the same upstream interpretation used for current distance calculation
- `status` typically reflects `OnTrack` or similar upstream state

### Derived Channels

- `distance`
  - accumulated lap distance
- `relativeDistance`
  - normalized progress through the lap, usually between `0` and `1`

What to expect:

- `distance` is the preferred x-axis for motorsport telemetry charts
- `relativeDistance` is useful when you want normalized overlays independent of exact lap length

## Chart-Ready Helpers

`TelemetryTrace` already exposes helpers for the most common chart series:

```swift
telemetry.speedSeriesByDistance()
telemetry.throttleSeriesByDistance()
telemetry.brakeSeriesByDistance()
telemetry.gearSeriesByDistance()
telemetry.rpmSeriesByDistance()
telemetry.trackMap()
```

These return:

- `[ChartPoint<Double>]` for speed
- `[ChartPoint<Double>]` for throttle
- `[ChartPoint<Bool>]` for brake
- `[ChartPoint<Int>]` for gear
- `[ChartPoint<Double>]` for RPM
- `[TrackPoint]` for the track map

This means that users can already generate charts for:

- speed vs distance
- throttle vs distance
- brake vs distance
- gear vs distance
- RPM vs distance
- XY track map

## Comparing Two Laps

The library now exposes a dedicated public comparison API.

Typical flow:

```swift
let referenceLap = try await session.fastestLap(driver: "16")
let comparedLap = try await session.fastestLap(driver: "55")

let comparison = try await session.compareTelemetry(
    referenceLap: referenceLap!,
    comparedLap: comparedLap!
)
```

Or, if you want the highest-level convenience path:

```swift
let comparison = try await session.compareFastestLaps(
    referenceDriver: "16",
    comparedDriver: "55"
)
```

### What a `TelemetryComparison` Contains

`TelemetryComparison` contains:

```swift
public struct TelemetryComparison: Sendable {
    public let reference: TelemetryTrace
    public let compared: TelemetryTrace
    public let samples: [TelemetryComparisonSample]
    public var finalDelta: TimeInterval? { get }
}
```

Each `TelemetryComparisonSample` contains both laps at the same aligned progress point:

```swift
public struct TelemetryComparisonSample: Sendable, Hashable {
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

### What to Expect from Comparison Data

- the comparison is aligned on shared lap progress using `relativeDistance`
- `distance` is included when it can be derived from the aligned pair
- `delta` is always `compared - reference`
- positive `delta` means the compared lap is slower at that point
- negative `delta` means the compared lap is ahead at that point

### Comparison Chart Helpers

`TelemetryComparison` already exposes helpers for the most common overlay charts:

```swift
comparison.deltaSeriesByDistance()
comparison.deltaSeriesByRelativeDistance()

comparison.referenceSpeedSeriesByDistance()
comparison.comparedSpeedSeriesByDistance()

comparison.referenceThrottleSeriesByDistance()
comparison.comparedThrottleSeriesByDistance()

comparison.referenceRPMSeriesByDistance()
comparison.comparedRPMSeriesByDistance()

comparison.referenceGearSeriesByDistance()
comparison.comparedGearSeriesByDistance()

comparison.referenceBrakeSeriesByDistance()
comparison.comparedBrakeSeriesByDistance()
```

This means that users can now generate charts for:

- speed overlays
- throttle overlays
- RPM overlays
- gear overlays
- brake overlays
- delta time vs distance

## Practical Expectations Per Channel

### Speed

Good for:

- line charts
- corner entry/exit comparisons
- top-speed comparisons

What to expect:

- one of the most reliable and useful telemetry channels
- already validated against FastF1 on the current reference flow

### RPM

Good for:

- line charts
- shift pattern analysis
- gear change correlation

What to expect:

- useful together with `gear` and `speed`

### Gear

Good for:

- step charts
- shift point analysis

What to expect:

- discrete values
- should generally not be rendered as a smooth interpolated curve

### Brake

Good for:

- on/off overlays
- braking zone visualization

What to expect:

- boolean values
- often best rendered as `0/1`, a step plot, or highlighted regions

### Throttle

Good for:

- throttle trace overlays
- traction and exit analysis

What to expect:

- continuous-style signal
- useful in combination with brake and speed

### DRS

Good for:

- activation overlays
- distinguishing open/closed DRS sections

What to expect:

- raw numeric state from upstream telemetry
- consumers may want to map raw values into simpler states later

### Track Position

Good for:

- track map plotting
- corner localization
- position-aware telemetry overlays

What to expect:

- enough for plotting a lap path
- useful as a geometry basis for future richer track-aware tools

## Optionality and Missing Data

Users should expect many telemetry fields to be optional:

- `speed`, `rpm`, `gear`, `brake`, etc. are `Optional`
- position coordinates are also `Optional`

Why:

- different upstream streams do not line up perfectly
- merged telemetry may contain data that exists for one source but not another
- current implementation keeps the model honest instead of pretending all values always exist

Practical advice:

- when plotting, use chart helpers where possible
- when accessing raw `samples`, always handle missing values safely

## Current Reliability Level

The strongest supported workflow today is:

1. resolve a real session
2. choose a driver
3. get the fastest lap
4. extract telemetry for that lap
5. build charts from speed, brake, gear, RPM, throttle, and track position

This path has already been validated against FastF1 for a real session.

What is less mature:

- full session-wide lap reconstruction parity
- all generated lap edge cases
- some complex pit/interruption scenarios

## Example: Extracting Channels Manually

```swift
let telemetry = try await session.telemetry(for: lap)

for sample in telemetry.samples.prefix(5) {
    print(sample.lapTime)
    print(sample.speed)
    print(sample.rpm)
    print(sample.gear)
    print(sample.brake)
    print(sample.distance)
}
```

## Example: Preparing Data for Your Own Charting Layer

```swift
let speed = telemetry.speedSeriesByDistance()
let rpm = telemetry.rpmSeriesByDistance()
let gear = telemetry.gearSeriesByDistance()
let brake = telemetry.brakeSeriesByDistance()
```

This is currently the recommended way to prepare data for:

- Swift Charts
- custom Core Graphics rendering
- SVG generation
- PNG/PDF rendering in a future rendering module
