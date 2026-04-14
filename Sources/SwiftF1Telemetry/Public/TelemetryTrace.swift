import Foundation

/// Merged telemetry data for a specific driver and lap.
///
/// Obtain a trace via ``Session/telemetry(for:)``:
///
/// ```swift
/// let trace = try await session.telemetry(for: lap)
///
/// // Access raw samples
/// for sample in trace.samples {
///     print("\(sample.distance ?? 0)m — \(sample.speed ?? 0) km/h")
/// }
///
/// // Or use chart-ready helpers
/// let speed = trace.speedSeriesByDistance()   // [ChartPoint<Double>]
/// let track = trace.trackMap()                // [TrackPoint]
/// ```
public struct TelemetryTrace: Sendable, Codable {
    /// Driver racing number (e.g. `"1"`, `"16"`).
    public let driverNumber: String
    /// Lap number associated with these samples.
    public let lapNumber: Int
    /// Ordered telemetry samples for the lap, sorted by session time.
    public let samples: [TelemetrySample]

    public init(driverNumber: String, lapNumber: Int, samples: [TelemetrySample]) {
        self.driverNumber = driverNumber
        self.lapNumber = lapNumber
        self.samples = samples
    }
}

/// A single telemetry sample containing car data, position data, and derived values.
///
/// Most fields are optional because upstream data streams do not always overlap.
/// When accessing raw samples, always handle `nil` values:
///
/// ```swift
/// for sample in trace.samples {
///     if let speed = sample.speed, let dist = sample.distance {
///         print("\(dist)m: \(speed) km/h")
///     }
/// }
/// ```
public struct TelemetrySample: Sendable, Hashable, Codable {
    /// Elapsed time on the session telemetry clock, in seconds.
    public let sessionTime: TimeInterval
    /// Elapsed time since the start of the selected lap, in seconds.
    public let lapTime: TimeInterval
    /// Car speed in km/h when available.
    public let speed: Double?
    /// Engine RPM when available.
    public let rpm: Double?
    /// Throttle value when available.
    public let throttle: Double?
    /// Brake state when available.
    public let brake: Bool?
    /// Raw DRS state when available.
    public let drs: Int?
    /// Gear number when available.
    public let gear: Int?
    /// Track X coordinate when available.
    public let x: Double?
    /// Track Y coordinate when available.
    public let y: Double?
    /// Track Z coordinate when available.
    public let z: Double?
    /// Upstream position status such as `OnTrack` when available.
    public let status: String?
    /// Accumulated lap distance in meters when available.
    public let distance: Double?
    /// Normalized progress through the lap when available.
    public let relativeDistance: Double?
    /// Describes whether the sample originated from car data, position data, or merged/interpolated output.
    public let source: SampleSource

    public init(
        sessionTime: TimeInterval,
        lapTime: TimeInterval,
        speed: Double?,
        rpm: Double?,
        throttle: Double?,
        brake: Bool?,
        drs: Int?,
        gear: Int?,
        x: Double?,
        y: Double?,
        z: Double?,
        status: String?,
        distance: Double?,
        relativeDistance: Double?,
        source: SampleSource
    ) {
        self.sessionTime = sessionTime
        self.lapTime = lapTime
        self.speed = speed
        self.rpm = rpm
        self.throttle = throttle
        self.brake = brake
        self.drs = drs
        self.gear = gear
        self.x = x
        self.y = y
        self.z = z
        self.status = status
        self.distance = distance
        self.relativeDistance = relativeDistance
        self.source = source
    }
}

/// Indicates where a telemetry sample originated from.
///
/// - ``car``: Raw car telemetry (speed, RPM, gear, etc.).
/// - ``position``: Raw position data (x, y, z coordinates).
/// - ``merged``: Combined car + position data at a shared timestamp.
/// - ``interpolated``: Synthetically generated to fill gaps between samples.
public enum SampleSource: String, Sendable, Codable {
    case car
    case position
    case merged
    case interpolated
}
