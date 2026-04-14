import Testing
@testable import SwiftF1Telemetry

@Test func comparisonInterpolatesAndComputesDelta() throws {
    let reference = TelemetryTrace(
        driverNumber: "16",
        lapNumber: 20,
        samples: [
            TelemetrySample(sessionTime: 0, lapTime: 0, speed: 100, rpm: 9_000, throttle: 0.5, brake: false, drs: 1, gear: 4, x: 0, y: 0, z: 0, status: "OnTrack", distance: 0, relativeDistance: 0, source: .merged),
            TelemetrySample(sessionTime: 10, lapTime: 10, speed: 200, rpm: 10_000, throttle: 1.0, brake: false, drs: 1, gear: 7, x: 100, y: 0, z: 0, status: "OnTrack", distance: 100, relativeDistance: 1, source: .merged),
        ]
    )
    let compared = TelemetryTrace(
        driverNumber: "55",
        lapNumber: 19,
        samples: [
            TelemetrySample(sessionTime: 0, lapTime: 0, speed: 90, rpm: 8_800, throttle: 0.4, brake: false, drs: 1, gear: 4, x: 0, y: 0, z: 0, status: "OnTrack", distance: 0, relativeDistance: 0, source: .merged),
            TelemetrySample(sessionTime: 6, lapTime: 6, speed: 150, rpm: 9_500, throttle: 0.8, brake: false, drs: 1, gear: 6, x: 50, y: 0, z: 0, status: "OnTrack", distance: 50, relativeDistance: 0.5, source: .merged),
            TelemetrySample(sessionTime: 11, lapTime: 11, speed: 198, rpm: 9_950, throttle: 0.95, brake: true, drs: 0, gear: 7, x: 100, y: 0, z: 0, status: "OnTrack", distance: 100, relativeDistance: 1, source: .merged),
        ]
    )

    let comparison = try TelemetryComparisonCalculator().compare(reference: reference, compared: compared)

    #expect(comparison.samples.count == 3)
    #expect(comparison.samples[1].relativeDistance == 0.5)
    #expect(abs(comparison.samples[1].referenceLapTime - 5) < 0.000_1)
    #expect(abs(comparison.samples[1].comparedLapTime - 6) < 0.000_1)
    #expect(abs(comparison.samples[1].delta - 1) < 0.000_1)
    #expect(abs((comparison.samples[1].referenceSpeed ?? 0) - 150) < 0.000_1)
    #expect(abs((comparison.samples[1].comparedSpeed ?? 0) - 150) < 0.000_1)
    #expect(abs(comparison.samples[2].delta - 1) < 0.000_1)
    #expect(abs((comparison.finalDelta ?? 0) - 1) < 0.000_1)
    #expect(comparison.deltaSeriesByDistance().count == 3)
}

@Test func compareFastestLapsBuildsPublicComparison() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let session = try await client.session(year: 2026, meeting: "Monza", session: .qualifying)

    let comparison = try await session.compareFastestLaps(referenceDriver: "16", comparedDriver: "55")

    #expect(comparison.reference.driverNumber == "16")
    #expect(comparison.compared.driverNumber == "55")
    #expect(comparison.reference.lapNumber == 2)
    #expect(comparison.compared.lapNumber == 2)
    #expect(comparison.samples.isEmpty == false)
    #expect(comparison.samples.first?.relativeDistance == 0)
    #expect(comparison.samples.last?.relativeDistance == 1)
    #expect(abs((comparison.finalDelta ?? 0) - 0.4) < 0.000_1)
    #expect(comparison.referenceSpeedSeriesByDistance().isEmpty == false)
    #expect(comparison.comparedSpeedSeriesByDistance().isEmpty == false)
}
