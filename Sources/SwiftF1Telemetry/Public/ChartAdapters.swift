import Foundation

public struct ChartPoint<Value: Sendable>: Sendable {
    public let x: Double
    public let y: Value

    public init(x: Double, y: Value) {
        self.x = x
        self.y = y
    }
}

public struct TrackPoint: Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

extension ChartPoint: Codable where Value: Codable {}
extension TrackPoint: Codable {}

public extension TelemetryTrace {
    func speedSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let speed = sample.speed else { return nil }
            return ChartPoint(x: distance, y: speed)
        }
    }

    func throttleSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let throttle = sample.throttle else { return nil }
            return ChartPoint(x: distance, y: throttle)
        }
    }

    func brakeSeriesByDistance() -> [ChartPoint<Bool>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let brake = sample.brake else { return nil }
            return ChartPoint(x: distance, y: brake)
        }
    }

    func gearSeriesByDistance() -> [ChartPoint<Int>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let gear = sample.gear else { return nil }
            return ChartPoint(x: distance, y: gear)
        }
    }

    func rpmSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let rpm = sample.rpm else { return nil }
            return ChartPoint(x: distance, y: rpm)
        }
    }

    func trackMap() -> [TrackPoint] {
        samples.compactMap { sample in
            guard let x = sample.x, let y = sample.y else { return nil }
            return TrackPoint(x: x, y: y)
        }
    }
}
