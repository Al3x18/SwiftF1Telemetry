import Foundation

/// A telemetry trace for a specific driver and lap.
public struct TelemetryTrace: Sendable {
    /// Driver racing number.
    public let driverNumber: String
    /// Lap number associated with these samples.
    public let lapNumber: Int
    /// Ordered telemetry samples for the lap.
    public let samples: [TelemetrySample]

    public init(driverNumber: String, lapNumber: Int, samples: [TelemetrySample]) {
        self.driverNumber = driverNumber
        self.lapNumber = lapNumber
        self.samples = samples
    }
}

/// A single telemetry sample containing car data, position data, and derived values.
public struct TelemetrySample: Sendable, Hashable {
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
public enum SampleSource: String, Sendable, Codable {
    case car
    case position
    case merged
    case interpolated
}
