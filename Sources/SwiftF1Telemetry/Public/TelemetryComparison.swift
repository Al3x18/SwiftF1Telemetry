import Foundation

/// A lap-to-lap telemetry comparison aligned on a shared lap progress axis.
public struct TelemetryComparison: Sendable, Codable {
    /// The telemetry trace used as the baseline for delta calculations.
    public let reference: TelemetryTrace
    /// The telemetry trace compared against the reference trace.
    public let compared: TelemetryTrace
    /// Ordered samples aligned on a shared progress axis.
    public let samples: [TelemetryComparisonSample]

    public init(reference: TelemetryTrace, compared: TelemetryTrace, samples: [TelemetryComparisonSample]) {
        self.reference = reference
        self.compared = compared
        self.samples = samples
    }

    /// The final lap-time delta at the end of the aligned lap.
    public var finalDelta: TimeInterval? {
        samples.last?.delta
    }
}

/// A single aligned comparison sample for two laps.
public struct TelemetryComparisonSample: Sendable, Hashable, Codable {
    /// Shared lap distance, in meters, when available.
    public let distance: Double?
    /// Normalized lap progress from `0.0` to `1.0`.
    public let relativeDistance: Double
    /// Reference lap time at this progress point.
    public let referenceLapTime: TimeInterval
    /// Compared lap time at this progress point.
    public let comparedLapTime: TimeInterval
    /// Positive means the compared lap is slower than the reference at this point.
    public let delta: TimeInterval
    /// Reference telemetry values.
    public let referenceSpeed: Double?
    public let referenceRPM: Double?
    public let referenceThrottle: Double?
    public let referenceBrake: Bool?
    public let referenceDRS: Int?
    public let referenceGear: Int?
    /// Compared telemetry values.
    public let comparedSpeed: Double?
    public let comparedRPM: Double?
    public let comparedThrottle: Double?
    public let comparedBrake: Bool?
    public let comparedDRS: Int?
    public let comparedGear: Int?

    public init(
        distance: Double?,
        relativeDistance: Double,
        referenceLapTime: TimeInterval,
        comparedLapTime: TimeInterval,
        delta: TimeInterval,
        referenceSpeed: Double?,
        referenceRPM: Double?,
        referenceThrottle: Double?,
        referenceBrake: Bool?,
        referenceDRS: Int?,
        referenceGear: Int?,
        comparedSpeed: Double?,
        comparedRPM: Double?,
        comparedThrottle: Double?,
        comparedBrake: Bool?,
        comparedDRS: Int?,
        comparedGear: Int?
    ) {
        self.distance = distance
        self.relativeDistance = relativeDistance
        self.referenceLapTime = referenceLapTime
        self.comparedLapTime = comparedLapTime
        self.delta = delta
        self.referenceSpeed = referenceSpeed
        self.referenceRPM = referenceRPM
        self.referenceThrottle = referenceThrottle
        self.referenceBrake = referenceBrake
        self.referenceDRS = referenceDRS
        self.referenceGear = referenceGear
        self.comparedSpeed = comparedSpeed
        self.comparedRPM = comparedRPM
        self.comparedThrottle = comparedThrottle
        self.comparedBrake = comparedBrake
        self.comparedDRS = comparedDRS
        self.comparedGear = comparedGear
    }
}

public extension TelemetryComparison {
    func deltaSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance else { return nil }
            return ChartPoint(x: distance, y: sample.delta)
        }
    }

    func deltaSeriesByRelativeDistance() -> [ChartPoint<Double>] {
        samples.map { ChartPoint(x: $0.relativeDistance, y: $0.delta) }
    }

    func referenceSpeedSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let speed = sample.referenceSpeed else { return nil }
            return ChartPoint(x: distance, y: speed)
        }
    }

    func comparedSpeedSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let speed = sample.comparedSpeed else { return nil }
            return ChartPoint(x: distance, y: speed)
        }
    }

    func referenceThrottleSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let throttle = sample.referenceThrottle else { return nil }
            return ChartPoint(x: distance, y: throttle)
        }
    }

    func comparedThrottleSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let throttle = sample.comparedThrottle else { return nil }
            return ChartPoint(x: distance, y: throttle)
        }
    }

    func referenceRPMSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let rpm = sample.referenceRPM else { return nil }
            return ChartPoint(x: distance, y: rpm)
        }
    }

    func comparedRPMSeriesByDistance() -> [ChartPoint<Double>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let rpm = sample.comparedRPM else { return nil }
            return ChartPoint(x: distance, y: rpm)
        }
    }

    func referenceGearSeriesByDistance() -> [ChartPoint<Int>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let gear = sample.referenceGear else { return nil }
            return ChartPoint(x: distance, y: gear)
        }
    }

    func comparedGearSeriesByDistance() -> [ChartPoint<Int>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let gear = sample.comparedGear else { return nil }
            return ChartPoint(x: distance, y: gear)
        }
    }

    func referenceBrakeSeriesByDistance() -> [ChartPoint<Bool>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let brake = sample.referenceBrake else { return nil }
            return ChartPoint(x: distance, y: brake)
        }
    }

    func comparedBrakeSeriesByDistance() -> [ChartPoint<Bool>] {
        samples.compactMap { sample in
            guard let distance = sample.distance, let brake = sample.comparedBrake else { return nil }
            return ChartPoint(x: distance, y: brake)
        }
    }
}
