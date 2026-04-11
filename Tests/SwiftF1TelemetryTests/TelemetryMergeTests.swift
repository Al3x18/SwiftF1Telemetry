import Testing
@testable import SwiftF1Telemetry

@Test func telemetryMergeUsesNearestPositionSample() {
    let lap = Lap(
        driverNumber: "16",
        lapNumber: 2,
        startSessionTime: 90,
        endSessionTime: 178,
        lapTime: 88,
        sector1: nil,
        sector2: nil,
        sector3: nil,
        isAccurate: true
    )

    let carSamples = [
        CarSample(driverNumber: "16", sessionTime: 100, date: nil, speed: 200, rpm: 10_000, throttle: 1.0, brake: false, drs: 1, gear: 7),
        CarSample(driverNumber: "16", sessionTime: 110, date: nil, speed: 190, rpm: 9_800, throttle: 0.5, brake: true, drs: 0, gear: 5),
    ]
    let positionSamples = [
        PositionSample(driverNumber: "16", sessionTime: 99, date: nil, x: 10, y: 0, z: 0, status: "OnTrack"),
        PositionSample(driverNumber: "16", sessionTime: 112, date: nil, x: 20, y: 5, z: 0, status: "OnTrack"),
    ]

    let merged = TelemetryMerger().merge(carSamples: carSamples, positionSamples: positionSamples, lap: lap)
    #expect(merged.count == 2)
    #expect(merged[0].x == 10)
    #expect(merged[1].x == 20)
}
