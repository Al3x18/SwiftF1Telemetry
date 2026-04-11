import Foundation

public struct Session: Sendable {
    public let ref: SessionRef
    public let metadata: SessionMetadata

    private let backend: BackendProtocol
    private let timingParser: TimingParser
    private let carDataParser: CarDataParser
    private let positionParser: PositionParser
    private let lapSlicer: LapSlicer
    private let telemetryMerger: TelemetryMerger
    private let interpolator: Interpolator
    private let distanceCalculator: DistanceCalculator

    init(
        ref: SessionRef,
        metadata: SessionMetadata,
        backend: BackendProtocol,
        timingParser: TimingParser = TimingParser(),
        carDataParser: CarDataParser = CarDataParser(),
        positionParser: PositionParser = PositionParser(),
        lapSlicer: LapSlicer = LapSlicer(),
        telemetryMerger: TelemetryMerger = TelemetryMerger(),
        interpolator: Interpolator = Interpolator(),
        distanceCalculator: DistanceCalculator = DistanceCalculator()
    ) {
        self.ref = ref
        self.metadata = metadata
        self.backend = backend
        self.timingParser = timingParser
        self.carDataParser = carDataParser
        self.positionParser = positionParser
        self.lapSlicer = lapSlicer
        self.telemetryMerger = telemetryMerger
        self.interpolator = interpolator
        self.distanceCalculator = distanceCalculator
    }

    public func laps() async throws -> [Lap] {
        let data = try await backend.fetchTimingData(for: ref)
        return try timingParser.parseLaps(from: data).map { $0.toPublicLap() }
    }

    public func fastestLap(driver: String) async throws -> Lap? {
        let driverLaps = try await laps()
            .filter { $0.driverNumber == driver && $0.isAccurate }

        return driverLaps.min { lhs, rhs in
            switch (lhs.lapTime, rhs.lapTime) {
            case let (.some(left), .some(right)):
                return left < right
            case (.some, .none):
                return true
            default:
                return false
            }
        }
    }

    public func telemetry(for lap: Lap) async throws -> TelemetryTrace {
        async let carData = backend.fetchCarData(for: ref)
        async let positionData = backend.fetchPositionData(for: ref)

        let carSamples = try carDataParser.parseSamples(from: try await carData)
        let positionSamples = try positionParser.parseSamples(from: try await positionData)

        let slicedCar = lapSlicer.sliceCarSamples(carSamples, for: lap)
        let slicedPosition = lapSlicer.slicePositionSamples(positionSamples, for: lap)

        guard !slicedCar.isEmpty else {
            throw F1TelemetryError.telemetryUnavailable(driver: lap.driverNumber, lap: lap.lapNumber)
        }

        let merged = telemetryMerger.merge(carSamples: slicedCar, positionSamples: slicedPosition, lap: lap)
        let interpolated = interpolator.interpolate(samples: merged)
        let distanceReady = distanceCalculator.applyingDistance(to: interpolated)

        return TelemetryTrace(
            driverNumber: lap.driverNumber,
            lapNumber: lap.lapNumber,
            samples: distanceReady
        )
    }
}
