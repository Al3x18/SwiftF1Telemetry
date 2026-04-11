import Testing
@testable import SwiftF1Telemetry

@Test func lapSlicerFiltersByDriverAndTimeWindow() {
    let lap = Lap(
        driverNumber: "16",
        lapNumber: 2,
        startSessionTime: 90,
        endSessionTime: 150,
        lapTime: 60,
        sector1: nil,
        sector2: nil,
        sector3: nil,
        isAccurate: true
    )

    let samples = [
        CarSample(driverNumber: "16", sessionTime: 89, date: nil, speed: nil, rpm: nil, throttle: nil, brake: nil, drs: nil, gear: nil),
        CarSample(driverNumber: "16", sessionTime: 100, date: nil, speed: nil, rpm: nil, throttle: nil, brake: nil, drs: nil, gear: nil),
        CarSample(driverNumber: "55", sessionTime: 110, date: nil, speed: nil, rpm: nil, throttle: nil, brake: nil, drs: nil, gear: nil),
        CarSample(driverNumber: "16", sessionTime: 151, date: nil, speed: nil, rpm: nil, throttle: nil, brake: nil, drs: nil, gear: nil),
    ]

    let sliced = LapSlicer().sliceCarSamples(samples, for: lap)
    #expect(sliced.count == 1)
    #expect(sliced.first?.sessionTime == 100)
}
