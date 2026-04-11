import Foundation

public struct TelemetryTrace: Sendable {
    public let driverNumber: String
    public let lapNumber: Int
    public let samples: [TelemetrySample]

    public init(driverNumber: String, lapNumber: Int, samples: [TelemetrySample]) {
        self.driverNumber = driverNumber
        self.lapNumber = lapNumber
        self.samples = samples
    }
}

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

public enum SampleSource: String, Sendable, Codable {
    case car
    case position
    case merged
    case interpolated
}
