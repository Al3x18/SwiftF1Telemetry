# API: Session and Core Models

This section documents `Session` APIs and the core session/lap models.

## When to read this page

- You are handling session lifecycle and lap selection.
- You need model-level details for session metadata and lap structures.

## `Session`

```swift
public struct Session: Sendable {
    public let ref: SessionRef
    public let metadata: SessionMetadata

    public func resolveDriverNumber(_ identifier: String) async throws -> String
    public func laps() async throws -> [Lap]
    public func fastestLap(driver: String) async throws -> Lap?
    public func telemetry(for lap: Lap) async throws -> TelemetryTrace
    public func compare(reference: TelemetryTrace, compared: TelemetryTrace) throws -> TelemetryComparison
    public func compareTelemetry(referenceLap: Lap, comparedLap: Lap) async throws -> TelemetryComparison
    public func compareFastestLaps(referenceDriver: String, comparedDriver: String) async throws -> TelemetryComparison
}
```

### `laps()`

Returns:

- `[Lap]`

What the caller should expect:

- parsed laps for the session
- useful and already functional for the fastest-lap workflow
- not yet full FastF1 parity for every generated or edge-case lap

### `fastestLap(driver:)`

Parameters:

- `driver`: racing number, last name, abbreviation, or full name — for example `"16"`, `"Leclerc"`, or `"LEC"`

Returns:

- `Lap?`

What the caller should expect:

- the fastest valid lap for that driver if one exists
- `nil` if no valid lap is available for that driver
- name-based resolution uses the session's `DriverList.jsonStream` from the archive

### `resolveDriverNumber(_:)`

Parameters:

- `identifier`: a racing number or name-based identifier

Returns:

- `String` — the resolved racing number

What the caller should expect:

- numbers pass through unchanged
- names, abbreviations, and partial matches are resolved against the session driver list
- throws `noLapsAvailable` if no match is found

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

### `EventDescriptor`

```swift
public struct EventDescriptor: Sendable, Hashable, Codable {
    public let year: Int
    public let name: String
    public let officialName: String
    public let location: String
    public let circuitName: String
}
```

### `SessionDescriptor`

```swift
public struct SessionDescriptor: Sendable, Hashable, Codable {
    public let year: Int
    public let eventName: String
    public let sessionType: SessionType
    public let name: String
    public let startDate: Date?
    public let endDate: Date?
}
```

### `DriverDescriptor`

```swift
public struct DriverDescriptor: Sendable, Hashable, Codable {
    public let driverNumber: String
    public let firstName: String?
    public let lastName: String?
    public let fullName: String?
    public let abbreviation: String?
    public let broadcastName: String?
    public let teamName: String?
    public let teamColour: String?
    public let countryCode: String?
}
```

What the caller should expect:

- name, team, and abbreviation fields are populated when the archive provides `DriverList.jsonStream` for the session
- all fields except `driverNumber` are optional for backward compatibility
- `abbreviation` is the three-letter code (e.g. `"LEC"`, `"HAM"`)

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
