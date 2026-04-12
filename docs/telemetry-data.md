# Telemetry Data Guide

This document explains which telemetry data is currently available for a lap, how to extract it, and what users should expect when working with it.

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

## What a `TelemetryTrace` Contains

`TelemetryTrace` contains:

```swift
public struct TelemetryTrace: Sendable {
    public let driverNumber: String
    public let lapNumber: Int
    public let samples: [TelemetrySample]
}
```

Each `TelemetrySample` may contain:

```swift
public struct TelemetrySample: Sendable, Hashable {
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
- advanced interpolation behavior across all use cases

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
