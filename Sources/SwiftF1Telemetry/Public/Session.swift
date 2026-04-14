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
        fastestLap(for: driver, in: try await laps())
    }

    /// Builds merged telemetry for the provided lap.
    ///
    /// Fetches car data and position data, slices them to the lap window,
    /// merges, and computes distance.
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
    /// - Returns: A ``TelemetryTrace`` containing the ordered samples for the lap,
    ///   with ``TelemetryTrace/officialLapTime`` set from ``Lap/lapTime``.
    public func telemetry(for lap: Lap) async throws -> TelemetryTrace {
        let data = try await fetchSessionData()
        return try buildTelemetryTrace(for: lap, carSamples: data.car, positionSamples: data.position)
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
        let data = try await fetchSessionData()
        return try compare(
            reference: buildTelemetryTrace(for: referenceLap, carSamples: data.car, positionSamples: data.position),
            compared: buildTelemetryTrace(for: comparedLap, carSamples: data.car, positionSamples: data.position)
        )
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
        async let allLaps = laps()
        async let data = fetchSessionData()

        let resolvedLaps = try await allLaps

        guard let referenceLap = fastestLap(for: referenceDriver, in: resolvedLaps) else {
            throw F1TelemetryError.noLapsAvailable(driver: referenceDriver)
        }

        guard let comparedLap = fastestLap(for: comparedDriver, in: resolvedLaps) else {
            throw F1TelemetryError.noLapsAvailable(driver: comparedDriver)
        }

        let sessionData = try await data
        return try compare(
            reference: buildTelemetryTrace(for: referenceLap, carSamples: sessionData.car, positionSamples: sessionData.position),
            compared: buildTelemetryTrace(for: comparedLap, carSamples: sessionData.car, positionSamples: sessionData.position)
        )
    }

    private func fetchSessionData() async throws -> (car: [CarSample], position: [PositionSample]) {
        async let carData = backend.fetchCarData(for: ref)
        async let positionData = backend.fetchPositionData(for: ref)
        return (
            car: try carDataParser.parseSamples(from: try await carData),
            position: try positionParser.parseSamples(from: try await positionData)
        )
    }

    private func fastestLap(for driver: String, in laps: [Lap]) -> Lap? {
        laps
            .filter { $0.driverNumber == driver && $0.isAccurate && $0.lapTime != nil }
            .min { $0.lapTime! < $1.lapTime! }
    }

    private func buildTelemetryTrace(for lap: Lap, carSamples: [CarSample], positionSamples: [PositionSample]) throws -> TelemetryTrace {
        let slicedCar = lapSlicer.sliceCarSamples(carSamples, for: lap)
        let slicedPosition = lapSlicer.slicePositionSamples(positionSamples, for: lap)

        guard !slicedCar.isEmpty else {
            throw F1TelemetryError.telemetryUnavailable(driver: lap.driverNumber, lap: lap.lapNumber)
        }

        let merged = telemetryMerger.merge(carSamples: slicedCar, positionSamples: slicedPosition, lap: lap)
        let distanceReady = distanceCalculator.applyingDistance(to: merged)

        return TelemetryTrace(
            driverNumber: lap.driverNumber,
            lapNumber: lap.lapNumber,
            samples: distanceReady,
            officialLapTime: lap.lapTime
        )
    }
}
