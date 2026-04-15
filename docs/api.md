# SwiftF1Telemetry API Reference

This page is the API entry point and table of contents.

## When to read this page

- You need a quick map of the public API surface.
- You want to jump to a specific API area without scrolling a long single page.

If you are new to the package, start with:

- [Package Overview](overview.md)
- [Telemetry Data Guide](telemetry-data.md)

## API Sections

- [Client and Discovery APIs](api/client-and-discovery.md)
- [Session and Core Models](api/session-and-core-models.md)
- [Telemetry and Comparison APIs](api/telemetry-and-comparison.md)
- [Errors and Versioning](api/errors-and-versioning.md)

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

For lap-to-lap comparison:

```swift
let comparison = try await session.compareFastestLaps(
    referenceDriver: "16",
    comparedDriver: "55"
)

let delta = comparison.deltaSeriesByDistance()
let referenceSpeed = comparison.referenceSpeedSeriesByDistance()
let comparedSpeed = comparison.comparedSpeedSeriesByDistance()
```
