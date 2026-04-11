import Testing
@testable import SwiftF1Telemetry

@Test func chartAdaptersAndDistanceCalculationProduceUsableSeries() {
    let samples = [
        TelemetrySample(
            sessionTime: 0,
            lapTime: 0,
            speed: 100,
            rpm: 9_000,
            throttle: 0.6,
            brake: false,
            drs: 0,
            gear: 4,
            x: 0,
            y: 0,
            z: 0,
            status: "OnTrack",
            distance: nil,
            relativeDistance: nil,
            source: .merged
        ),
        TelemetrySample(
            sessionTime: 1,
            lapTime: 1,
            speed: 120,
            rpm: 10_000,
            throttle: 0.9,
            brake: false,
            drs: 1,
            gear: 5,
            x: 3,
            y: 4,
            z: 0,
            status: "OnTrack",
            distance: nil,
            relativeDistance: nil,
            source: .merged
        ),
    ]

    let trace = TelemetryTrace(
        driverNumber: "16",
        lapNumber: 1,
        samples: DistanceCalculator().applyingDistance(to: samples)
    )

    #expect(trace.speedSeriesByDistance().count == 2)
    #expect(trace.trackMap().count == 2)
    #expect(trace.samples.last?.distance == 0.5)
    #expect(trace.samples.last?.relativeDistance == 1)
}
