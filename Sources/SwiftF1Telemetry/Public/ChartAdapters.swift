import Foundation

/// A generic x/y data point for charting telemetry channels.
///
/// `x` is typically the lap distance in meters, while `y` carries the channel value.
///
/// ```swift
/// let point = ChartPoint(x: 1200.0, y: 310.5) // distance 1200 m, speed 310.5 km/h
/// ```
public struct ChartPoint<Value: Sendable>: Sendable {
    /// The x-axis value, typically lap distance in meters.
    public let x: Double
    /// The y-axis value for the telemetry channel.
    public let y: Value

    public init(x: Double, y: Value) {
        self.x = x
        self.y = y
    }
}

/// A 2-D coordinate point used for track-map rendering.
///
/// ```swift
/// let points: [TrackPoint] = telemetry.trackMap()
/// // Plot points.map(\.x) vs points.map(\.y) to draw the circuit layout.
/// ```
public struct TrackPoint: Sendable {
    /// Horizontal track coordinate.
    public let x: Double
    /// Vertical track coordinate.
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

extension ChartPoint: Codable where Value: Codable {}
extension TrackPoint: Codable {}

// MARK: - TelemetryTrace Chart Helpers

/// Chart-ready series extracted from a single ``TelemetryTrace``.
///
/// These helpers return arrays of ``ChartPoint`` or ``TrackPoint`` ready
/// for Swift Charts, Core Graphics, or any charting framework:
///
/// ```swift
/// let telemetry = try await session.telemetry(for: lap)
///
/// let speed = telemetry.speedSeriesByDistance()   // [ChartPoint<Double>]
/// let brake = telemetry.brakeSeriesByDistance()   // [ChartPoint<Bool>]
/// let track = telemetry.trackMap()                // [TrackPoint]
/// ```
public extension TelemetryTrace {
    /// Speed (km/h) vs lap distance (m).
    func speedSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let speed = sample.speed else { return nil }
            return ChartPoint(x: distance, y: speed)
        }
    }

    /// Throttle vs lap distance (m).
    func throttleSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let throttle = sample.throttle else { return nil }
            return ChartPoint(x: distance, y: throttle)
        }
    }

    /// Brake state vs lap distance (m).
    func brakeSeriesByDistance() -> [ChartPoint<Bool>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let brake = sample.brake else { return nil }
            return ChartPoint(x: distance, y: brake)
        }
    }

    /// Gear number vs lap distance (m).
    func gearSeriesByDistance() -> [ChartPoint<Int>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let gear = sample.gear else { return nil }
            return ChartPoint(x: distance, y: gear)
        }
    }

    /// Engine RPM vs lap distance (m).
    func rpmSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let rpm = sample.rpm else { return nil }
            return ChartPoint(x: distance, y: rpm)
        }
    }

    /// 2-D track map built from position coordinates.
    func trackMap() -> [TrackPoint] {
        samples.compactMap { sample in
            guard let x = sample.x, let y = sample.y else { return nil }
            return TrackPoint(x: x, y: y)
        }
    }
}
