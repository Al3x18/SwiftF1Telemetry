import Foundation

/// A resolved Formula 1 session that can provide laps and telemetry.
///
/// You obtain a `Session` from ``F1Client/session(year:meeting:session:)``:
///
/// ```swift
/// let client = F1Client()
/// let session = try await client.session(
///     year: 2024,
///     meeting: "Monza",
///     session: .qualifying
/// )
///
/// // List all laps
/// let laps = try await session.laps()
///
/// // Get the fastest lap for a driver
/// guard let lap = try await session.fastestLap(driver: "16") else { return }
///
/// // Extract telemetry
/// let telemetry = try await session.telemetry(for: lap)
/// ```
public struct Session: Sendable {
    /// Stable reference information for the resolved session.
    public let ref: SessionRef
    /// Human-readable session metadata such as meeting and circuit names.
    public let metadata: SessionMetadata

    private let backend: BackendProtocol
    private let timingParser: TimingParser
    private let carDataParser: CarDataParser
    private let positionParser: PositionParser
    private let lapSlicer: LapSlicer
    private let telemetryMerger: TelemetryMerger
    private let interpolator: Interpolator
    private let distanceCalculator: DistanceCalculator
    private let comparisonCalculator: TelemetryComparisonCalculator

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
        distanceCalculator: DistanceCalculator = DistanceCalculator(),
        comparisonCalculator: TelemetryComparisonCalculator = TelemetryComparisonCalculator()
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
        self.comparisonCalculator = comparisonCalculator
    }

    /// Returns all parsed laps for this session.
    ///
    /// ```swift
    /// let laps = try await session.laps()
    /// for lap in laps where lap.driverNumber == "1" {
    ///     print("Lap \(lap.lapNumber): \(lap.lapTime ?? 0)")
    /// }
    /// ```
    public func laps() async throws -> [Lap] {
        let data = try await backend.fetchTimingData(for: ref)
        return try timingParser.parseLaps(from: data).map { $0.toPublicLap() }
    }

    /// Returns the fastest accurate lap for the specified driver number, if one exists.
    ///
    /// ```swift
    /// if let fastest = try await session.fastestLap(driver: "16") {
    ///     print("Best lap: \(fastest.lapTime ?? 0)s")
    /// }
    /// ```
    ///
    /// - Parameter driver: The driver's racing number (e.g. `"1"`, `"16"`, `"55"`).
    /// - Returns: The ``Lap`` with the shortest `lapTime` among accurate laps, or `nil`.
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

    /// Builds merged telemetry for the provided lap.
    ///
    /// Fetches car data and position data, slices them to the lap window,
    /// merges, interpolates, and computes distance.
    ///
    /// ```swift
    /// let lap = try await session.fastestLap(driver: "16")!
    /// let telemetry = try await session.telemetry(for: lap)
    ///
    /// let speed = telemetry.speedSeriesByDistance()
    /// let track = telemetry.trackMap()
    /// ```
    ///
    /// - Parameter lap: The ``Lap`` to extract telemetry for.
    /// - Returns: A ``TelemetryTrace`` containing the ordered samples for the lap.
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

    /// Compares two telemetry traces aligned on shared lap progress.
    ///
    /// Use this when you already have two ``TelemetryTrace`` instances:
    ///
    /// ```swift
    /// let refTrace = try await session.telemetry(for: refLap)
    /// let cmpTrace = try await session.telemetry(for: cmpLap)
    /// let comparison = try session.compare(reference: refTrace, compared: cmpTrace)
    /// ```
    ///
    /// - Parameters:
    ///   - reference: The baseline trace for delta calculations.
    ///   - compared: The trace compared against the baseline.
    /// - Returns: A ``TelemetryComparison`` with aligned samples and deltas.
    public func compare(reference: TelemetryTrace, compared: TelemetryTrace) throws -> TelemetryComparison {
        try comparisonCalculator.compare(reference: reference, compared: compared)
    }

    /// Builds and compares telemetry for two already selected laps.
    ///
    /// A convenience that fetches telemetry for both laps concurrently and compares them:
    ///
    /// ```swift
    /// let ref = try await session.fastestLap(driver: "16")!
    /// let cmp = try await session.fastestLap(driver: "55")!
    /// let comparison = try await session.compareTelemetry(
    ///     referenceLap: ref,
    ///     comparedLap: cmp
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - referenceLap: The baseline ``Lap``.
    ///   - comparedLap: The ``Lap`` compared against the baseline.
    /// - Returns: A ``TelemetryComparison`` with aligned samples and deltas.
    public func compareTelemetry(referenceLap: Lap, comparedLap: Lap) async throws -> TelemetryComparison {
        async let referenceTelemetry = telemetry(for: referenceLap)
        async let comparedTelemetry = telemetry(for: comparedLap)

        return try compare(reference: try await referenceTelemetry, compared: try await comparedTelemetry)
    }

    /// Compares the fastest valid laps for the two specified drivers.
    ///
    /// The highest-level comparison API — resolves fastest laps, fetches telemetry,
    /// and aligns them in a single call:
    ///
    /// ```swift
    /// let comparison = try await session.compareFastestLaps(
    ///     referenceDriver: "16",
    ///     comparedDriver: "55"
    /// )
    /// print("Final delta: \(comparison.finalDelta ?? 0)s")
    ///
    /// let delta = comparison.deltaSeriesByDistance()   // ready for charting
    /// ```
    ///
    /// - Parameters:
    ///   - referenceDriver: Racing number of the baseline driver (e.g. `"16"`).
    ///   - comparedDriver: Racing number of the compared driver (e.g. `"55"`).
    /// - Returns: A ``TelemetryComparison`` with aligned samples and deltas.
    public func compareFastestLaps(referenceDriver: String, comparedDriver: String) async throws -> TelemetryComparison {
        guard let referenceLap = try await fastestLap(driver: referenceDriver) else {
            throw F1TelemetryError.noLapsAvailable(driver: referenceDriver)
        }

        guard let comparedLap = try await fastestLap(driver: comparedDriver) else {
            throw F1TelemetryError.noLapsAvailable(driver: comparedDriver)
        }

        return try await compareTelemetry(referenceLap: referenceLap, comparedLap: comparedLap)
    }
}
