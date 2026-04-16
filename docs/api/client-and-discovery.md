# API: Client and Discovery

This section documents the `F1Client` entry point, configuration options, and discovery APIs.

## When to read this page

- You need to initialize the client and configure cache/network behavior.
- You want guided discovery flows for years, events, sessions, and drivers.

## `F1Client`

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
    public func availableYears() async throws -> [Int]
    public func availableEvents(in year: Int) async throws -> [EventDescriptor]
    public func availableSessions(in year: Int, event: String) async throws -> [SessionDescriptor]
    public func availableDrivers(in year: Int, event: String, session: SessionType) async throws -> [DriverDescriptor]
    public func clearCache() async throws
    public func cacheSizeInMB() async throws -> Double
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
- `availableYears()` returns archive-backed years that can currently be discovered for telemetry workflows
- `availableEvents(in:)` returns discoverable events for a season year
- `availableSessions(in:event:)` returns discoverable sessions for an event, filtered to session types this library can open
- `availableDrivers(in:event:session:)` returns driver numbers that have lap-backed telemetry for the selected session
- `clearCache()` removes all cached raw payloads from the configured cache directory
- `cacheSizeInMB()` returns the current on-disk cache size in megabytes as a `Double`

## `F1Client.Configuration`

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
    case noCache
    case minimum
    case medium
    case large
    case extraLarge
    case unlimited
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

- `.noCache`: caching is fully bypassed (no reads/writes)
- `.minimum`: up to `50 MB` and used by default
- `.medium`: up to `100 MB`
- `.large`: up to `200 MB`
- `.extraLarge`: up to `400 MB`
- `.unlimited`: caching stays enabled with no size limit

## Discovery API

### `availableYears()`

Returns:

- `[Int]`

What the caller should expect:

- archive-backed years that the library can currently discover
- intended for building year pickers instead of hard-coded input
- throws `yearNotAvailable` when the selected year is not exposed by archive-backed discovery

### `availableEvents(in:)`

Returns:

- `[EventDescriptor]`

What the caller should expect:

- discoverable events for a season year
- event names suitable for passing back into session-resolution APIs
- throws `yearNotAvailable` if the year itself is not discoverable

### `availableSessions(in:event:)`

Returns:

- `[SessionDescriptor]`

What the caller should expect:

- only sessions that map to the library's supported `SessionType` values
- sessions without archive timing paths are excluded
- throws `yearNotAvailable` if the year is not discoverable
- throws `eventNotAvailable` if the event cannot be matched for that year
- throws `sessionNotAvailable` if the event exists but none of its sessions are usable by the library

### `availableDrivers(in:event:session:)`

Returns:

- `[DriverDescriptor]`

```swift
let years = try await client.availableYears()
let events = try await client.availableEvents(in: 2024)
let sessions = try await client.availableSessions(in: 2024, event: "Monza")
let drivers = try await client.availableDrivers(in: 2024, event: "Monza", session: .qualifying)
```

What the caller should expect:

- driver numbers derived from real lap-backed session data
- descriptors include first name, last name, abbreviation, team name, and country code when the archive provides `DriverList.jsonStream`
- useful for building a guided telemetry picker without manual guessing
- throws `yearNotAvailable`, `eventNotAvailable`, or `sessionNotAvailable` when the requested scope is not discoverable
- throws `driversNotAvailable` when the session resolves but no lap-backed drivers are available
