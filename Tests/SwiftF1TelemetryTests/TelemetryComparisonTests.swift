import Testing
@testable import SwiftF1Telemetry

// MARK: - Helpers

private func sample(
    sessionTime: Double,
    lapTime: Double,
    speed: Double = 200,
    x: Double,
    y: Double,
    distance: Double? = nil,
    relativeDistance: Double? = nil
) -> TelemetrySample {
    TelemetrySample(
        sessionTime: sessionTime,
        lapTime: lapTime,
        speed: speed,
        rpm: 10_000,
        throttle: 0.8,
        brake: false,
        drs: 1,
        gear: 6,
        x: x,
        y: y,
        z: 0,
        status: "OnTrack",
        distance: distance,
        relativeDistance: relativeDistance,
        source: .merged
    )
}

// MARK: - Original tests

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
    #expect(abs((comparison.finalDelta ?? 0) - 0.8) < 0.000_1)
    #expect(comparison.referenceSpeedSeriesByDistance().isEmpty == false)
    #expect(comparison.comparedSpeedSeriesByDistance().isEmpty == false)
}

// MARK: - DistanceCalculator: distance-based relativeDistance

@Test func distanceCalculatorUsesPhysicalDistanceNotIndex() {
    let calculator = DistanceCalculator()

    // Positions in 1/10 meter. Segments: 100m, 200m, 100m = 400m total
    let samples = [
        sample(sessionTime: 0,  lapTime: 0,  x: 0,    y: 0,    distance: nil, relativeDistance: nil),
        sample(sessionTime: 5,  lapTime: 5,  x: 1000, y: 0,    distance: nil, relativeDistance: nil),
        sample(sessionTime: 15, lapTime: 15, x: 1000, y: 2000, distance: nil, relativeDistance: nil),
        sample(sessionTime: 20, lapTime: 20, x: 2000, y: 2000, distance: nil, relativeDistance: nil),
    ]

    let result = calculator.applyingDistance(to: samples)

    // Distance-based: [0, 100/400=0.25, 300/400=0.75, 1.0]
    // Index-based (old bug) would give: [0, 0.333, 0.667, 1.0]
    #expect(result.count == 4)
    #expect(abs(result[0].relativeDistance! - 0.0) < 0.0001)
    #expect(abs(result[1].relativeDistance! - 0.25) < 0.0001)
    #expect(abs(result[2].relativeDistance! - 0.75) < 0.0001)
    #expect(abs(result[3].relativeDistance! - 1.0) < 0.0001)
}

@Test func distanceCalculatorDifferentSampleCountsSameTrack() {
    let calculator = DistanceCalculator()

    // Driver A: 3 samples over a 300m straight
    let driverA = [
        sample(sessionTime: 0,  lapTime: 0,  x: 0,    y: 0, distance: nil, relativeDistance: nil),
        sample(sessionTime: 10, lapTime: 10, x: 1500, y: 0, distance: nil, relativeDistance: nil),
        sample(sessionTime: 20, lapTime: 20, x: 3000, y: 0, distance: nil, relativeDistance: nil),
    ]

    // Driver B: 6 samples over the same 300m straight
    let driverB = [
        sample(sessionTime: 0,  lapTime: 0,   x: 0,    y: 0, distance: nil, relativeDistance: nil),
        sample(sessionTime: 4,  lapTime: 4,   x: 600,  y: 0, distance: nil, relativeDistance: nil),
        sample(sessionTime: 8,  lapTime: 8,   x: 1200, y: 0, distance: nil, relativeDistance: nil),
        sample(sessionTime: 12, lapTime: 12,  x: 1800, y: 0, distance: nil, relativeDistance: nil),
        sample(sessionTime: 16, lapTime: 16,  x: 2400, y: 0, distance: nil, relativeDistance: nil),
        sample(sessionTime: 20, lapTime: 20,  x: 3000, y: 0, distance: nil, relativeDistance: nil),
    ]

    let resultA = calculator.applyingDistance(to: driverA)
    let resultB = calculator.applyingDistance(to: driverB)

    // Both should have relativeDistance=0.5 at x=1500 (the midpoint)
    // Driver A: sample[1] at x=1500 → relDist = 150/300 = 0.5
    #expect(abs(resultA[1].relativeDistance! - 0.5) < 0.0001)

    // Driver B: sample[2] at x=1200 → relDist = 120/300 = 0.4
    //           sample[3] at x=1800 → relDist = 180/300 = 0.6
    #expect(abs(resultB[2].relativeDistance! - 0.4) < 0.0001)
    #expect(abs(resultB[3].relativeDistance! - 0.6) < 0.0001)

    // With index-based (old bug): resultA[1] = 1/2 = 0.5 (same by coincidence)
    // But resultB[2] = 2/5 = 0.4, resultB[3] = 3/5 = 0.6 (also same by coincidence for uniform spacing)
    // The difference shows with NON-uniform spacing — see distanceCalculatorUsesPhysicalDistanceNotIndex
}

// MARK: - Monza bug reproduction

@Test func finalDeltaMatchesOfficialGapMonzaScenario() throws {
    // Simulates the reported bug: Monza 2024 Q, #16 vs #55
    // Official gap: 83.219 - 83.226 = -0.007 (compared is faster)
    // Raw telemetry gap: 83.14 - 82.95 = +0.19 (WRONG — completely off)

    let reference = TelemetryTrace(
        driverNumber: "16",
        lapNumber: 5,
        samples: [
            sample(sessionTime: 100,    lapTime: 0,     x: 0,    y: 0,    distance: 0,    relativeDistance: 0),
            sample(sessionTime: 120.74, lapTime: 20.74, x: 1200, y: 200,  distance: 1400, relativeDistance: 0.25),
            sample(sessionTime: 141.48, lapTime: 41.48, x: 2500, y: 800,  distance: 2800, relativeDistance: 0.50),
            sample(sessionTime: 162.21, lapTime: 62.21, x: 3600, y: 400,  distance: 4200, relativeDistance: 0.75),
            sample(sessionTime: 182.95, lapTime: 82.95, x: 4800, y: 0,    distance: 5600, relativeDistance: 1.0),
        ],
        officialLapTime: 83.226
    )

    let compared = TelemetryTrace(
        driverNumber: "55",
        lapNumber: 5,
        samples: [
            sample(sessionTime: 200,    lapTime: 0,     x: 0,    y: 0,    distance: 0,    relativeDistance: 0),
            sample(sessionTime: 213.86, lapTime: 13.86, x: 800,  y: 100,  distance: 930,  relativeDistance: 0.166),
            sample(sessionTime: 227.71, lapTime: 27.71, x: 1600, y: 400,  distance: 1860, relativeDistance: 0.332),
            sample(sessionTime: 241.57, lapTime: 41.57, x: 2400, y: 700,  distance: 2790, relativeDistance: 0.498),
            sample(sessionTime: 255.43, lapTime: 55.43, x: 3100, y: 900,  distance: 3720, relativeDistance: 0.664),
            sample(sessionTime: 269.28, lapTime: 69.28, x: 3800, y: 500,  distance: 4650, relativeDistance: 0.830),
            sample(sessionTime: 283.14, lapTime: 83.14, x: 4800, y: 0,    distance: 5580, relativeDistance: 1.0),
        ],
        officialLapTime: 83.219
    )

    let comparison = try TelemetryComparisonCalculator().compare(reference: reference, compared: compared)

    let officialGap = 83.219 - 83.226  // -0.007

    #expect(comparison.finalDelta != nil)
    #expect(abs(comparison.finalDelta! - officialGap) < 0.001,
            "finalDelta \(comparison.finalDelta!) should match official gap \(officialGap)")

    // Verify the delta at the start is near zero (both start at the same point)
    #expect(abs(comparison.samples.first!.delta) < 0.5)

    // Verify the delta curve doesn't have wild jumps
    let deltas = comparison.samples.map(\.delta)
    for i in 1..<deltas.count {
        let jump = abs(deltas[i] - deltas[i - 1])
        #expect(jump < 2.0, "Delta jump at index \(i) is too large: \(jump)")
    }
}

// MARK: - Asymmetric sample count with large disparity

@Test func finalDeltaCorrectWithLargeAsymmetry() throws {
    // ref: 3 samples (sparse telemetry), cmp: 8 samples (dense telemetry)
    // Official: 90.0 vs 91.2 → gap = +1.2
    // Raw: lastLapTime 89.5 vs 90.8 → raw gap = +1.3 (drifted)

    let reference = TelemetryTrace(
        driverNumber: "1",
        lapNumber: 10,
        samples: [
            sample(sessionTime: 0,    lapTime: 0,    x: 0,    y: 0,    distance: 0,    relativeDistance: 0),
            sample(sessionTime: 44.5, lapTime: 44.5, x: 2400, y: 800,  distance: 2800, relativeDistance: 0.5),
            sample(sessionTime: 89.5, lapTime: 89.5, x: 4800, y: 0,    distance: 5600, relativeDistance: 1.0),
        ],
        officialLapTime: 90.0
    )

    let compared = TelemetryTrace(
        driverNumber: "4",
        lapNumber: 10,
        samples: [
            sample(sessionTime: 100,    lapTime: 0,     x: 0,    y: 0,    distance: 0,    relativeDistance: 0),
            sample(sessionTime: 113.0,  lapTime: 13.0,  x: 700,  y: 200,  distance: 800,  relativeDistance: 0.143),
            sample(sessionTime: 126.0,  lapTime: 26.0,  x: 1400, y: 500,  distance: 1600, relativeDistance: 0.286),
            sample(sessionTime: 139.0,  lapTime: 39.0,  x: 2100, y: 700,  distance: 2400, relativeDistance: 0.429),
            sample(sessionTime: 152.0,  lapTime: 52.0,  x: 2800, y: 800,  distance: 3200, relativeDistance: 0.571),
            sample(sessionTime: 165.0,  lapTime: 65.0,  x: 3500, y: 600,  distance: 4000, relativeDistance: 0.714),
            sample(sessionTime: 178.0,  lapTime: 78.0,  x: 4200, y: 300,  distance: 4800, relativeDistance: 0.857),
            sample(sessionTime: 190.8,  lapTime: 90.8,  x: 4800, y: 0,    distance: 5600, relativeDistance: 1.0),
        ],
        officialLapTime: 91.2
    )

    let comparison = try TelemetryComparisonCalculator().compare(reference: reference, compared: compared)

    let officialGap = 91.2 - 90.0  // +1.2

    #expect(abs(comparison.finalDelta! - officialGap) < 0.001,
            "finalDelta \(comparison.finalDelta!) should be \(officialGap), not raw gap 1.3")
}

// MARK: - Backward compatibility: no officialLapTime

@Test func finalDeltaUsesRawLapTimeWhenOfficialNotAvailable() throws {
    // Without officialLapTime, the raw lapTime values should be used
    let reference = TelemetryTrace(
        driverNumber: "1",
        lapNumber: 3,
        samples: [
            sample(sessionTime: 0,    lapTime: 0,    x: 0, y: 0, distance: 0,    relativeDistance: 0),
            sample(sessionTime: 89.5, lapTime: 89.5, x: 100, y: 0, distance: 100, relativeDistance: 1.0),
        ]
    )

    let compared = TelemetryTrace(
        driverNumber: "4",
        lapNumber: 3,
        samples: [
            sample(sessionTime: 100,   lapTime: 0,    x: 0, y: 0, distance: 0,    relativeDistance: 0),
            sample(sessionTime: 190.8, lapTime: 90.8, x: 100, y: 0, distance: 100, relativeDistance: 1.0),
        ]
    )

    let comparison = try TelemetryComparisonCalculator().compare(reference: reference, compared: compared)

    // No normalization → raw gap = 90.8 - 89.5 = 1.3
    #expect(abs(comparison.finalDelta! - 1.3) < 0.001)
}

// MARK: - Same official lap times → delta ≈ 0

@Test func finalDeltaIsNearZeroForIdenticalOfficialLapTimes() throws {
    // Both drivers have the same official lap time
    // Raw telemetry might differ, but normalization should force delta → 0

    let reference = TelemetryTrace(
        driverNumber: "44",
        lapNumber: 8,
        samples: [
            sample(sessionTime: 0,    lapTime: 0,    x: 0,    y: 0,   distance: 0,    relativeDistance: 0),
            sample(sessionTime: 42.0, lapTime: 42.0, x: 2000, y: 500, distance: 2800, relativeDistance: 0.5),
            sample(sessionTime: 84.6, lapTime: 84.6, x: 4000, y: 0,   distance: 5600, relativeDistance: 1.0),
        ],
        officialLapTime: 85.0
    )

    let compared = TelemetryTrace(
        driverNumber: "63",
        lapNumber: 8,
        samples: [
            sample(sessionTime: 100,    lapTime: 0,     x: 0,    y: 0,   distance: 0,    relativeDistance: 0),
            sample(sessionTime: 128.5,  lapTime: 28.5,  x: 1300, y: 300, distance: 1860, relativeDistance: 0.332),
            sample(sessionTime: 157.0,  lapTime: 57.0,  x: 2800, y: 700, distance: 3720, relativeDistance: 0.664),
            sample(sessionTime: 185.3,  lapTime: 85.3,  x: 4000, y: 0,   distance: 5600, relativeDistance: 1.0),
        ],
        officialLapTime: 85.0
    )

    let comparison = try TelemetryComparisonCalculator().compare(reference: reference, compared: compared)

    // Same officialLapTime → finalDelta must be 0
    #expect(abs(comparison.finalDelta!) < 0.001,
            "finalDelta should be ~0 for identical official times, got \(comparison.finalDelta!)")
}

// MARK: - Full pipeline: DistanceCalculator + normalization end-to-end

@Test func fullPipelineDistanceAndNormalizationCombined() throws {
    let calculator = DistanceCalculator()

    // Raw samples without distance/relativeDistance — positions in 1/10 meter
    // Segments: 100m, 200m, 100m = 400m total
    let rawRef = [
        sample(sessionTime: 0,    lapTime: 0,    speed: 150, x: 0,    y: 0,    distance: nil, relativeDistance: nil),
        sample(sessionTime: 25,   lapTime: 25,   speed: 200, x: 1000, y: 0,    distance: nil, relativeDistance: nil),
        sample(sessionTime: 55,   lapTime: 55,   speed: 180, x: 1000, y: 2000, distance: nil, relativeDistance: nil),
        sample(sessionTime: 79.6, lapTime: 79.6, speed: 160, x: 2000, y: 2000, distance: nil, relativeDistance: nil),
    ]

    // Different sample count and slightly different positions
    let rawCmp = [
        sample(sessionTime: 100,    lapTime: 0,     speed: 140, x: 0,    y: 0,    distance: nil, relativeDistance: nil),
        sample(sessionTime: 112,    lapTime: 12,    speed: 170, x: 500,  y: 0,    distance: nil, relativeDistance: nil),
        sample(sessionTime: 128,    lapTime: 28,    speed: 210, x: 1000, y: 0,    distance: nil, relativeDistance: nil),
        sample(sessionTime: 148,    lapTime: 48,    speed: 190, x: 1000, y: 1000, distance: nil, relativeDistance: nil),
        sample(sessionTime: 164,    lapTime: 64,    speed: 175, x: 1000, y: 2000, distance: nil, relativeDistance: nil),
        sample(sessionTime: 180.2,  lapTime: 80.2,  speed: 155, x: 2000, y: 2000, distance: nil, relativeDistance: nil),
    ]

    let refWithDist = calculator.applyingDistance(to: rawRef)
    let cmpWithDist = calculator.applyingDistance(to: rawCmp)

    // Verify distance-based relativeDistance was applied
    #expect(refWithDist.first!.relativeDistance! == 0)
    #expect(refWithDist.last!.relativeDistance! == 1.0)

    // ref: segments 100m, 200m, 100m = 400m → relDist [0, 0.25, 0.75, 1.0]
    #expect(abs(refWithDist[1].relativeDistance! - 0.25) < 0.0001)
    #expect(abs(refWithDist[2].relativeDistance! - 0.75) < 0.0001)

    let refTrace = TelemetryTrace(driverNumber: "16", lapNumber: 1, samples: refWithDist, officialLapTime: 80.0)
    let cmpTrace = TelemetryTrace(driverNumber: "55", lapNumber: 1, samples: cmpWithDist, officialLapTime: 80.5)

    let comparison = try TelemetryComparisonCalculator().compare(reference: refTrace, compared: cmpTrace)

    let officialGap = 80.5 - 80.0  // +0.5

    #expect(abs(comparison.finalDelta! - officialGap) < 0.001,
            "Full pipeline finalDelta \(comparison.finalDelta!) should match official gap \(officialGap)")
    #expect(comparison.samples.first!.relativeDistance == 0)
    #expect(comparison.samples.last!.relativeDistance == 1.0)
}

// MARK: - Normalization doesn't distort mid-lap delta shape

@Test func normalizationPreservesDeltaShapeAtMidLap() throws {
    // Both drivers on the same track, compared is slower in sector 1 but faster in sector 3
    // The delta should cross zero somewhere mid-lap

    let reference = TelemetryTrace(
        driverNumber: "1",
        lapNumber: 1,
        samples: [
            sample(sessionTime: 0,    lapTime: 0,    x: 0,    y: 0,    distance: 0,    relativeDistance: 0),
            sample(sessionTime: 20,   lapTime: 20,   x: 1000, y: 0,    distance: 1000, relativeDistance: 0.2),
            sample(sessionTime: 40,   lapTime: 40,   x: 2000, y: 500,  distance: 2000, relativeDistance: 0.4),
            sample(sessionTime: 60,   lapTime: 60,   x: 3000, y: 1000, distance: 3000, relativeDistance: 0.6),
            sample(sessionTime: 80,   lapTime: 80,   x: 4000, y: 500,  distance: 4000, relativeDistance: 0.8),
            sample(sessionTime: 99.5, lapTime: 99.5, x: 5000, y: 0,    distance: 5000, relativeDistance: 1.0),
        ],
        officialLapTime: 100.0
    )

    let compared = TelemetryTrace(
        driverNumber: "4",
        lapNumber: 1,
        samples: [
            sample(sessionTime: 200,    lapTime: 0,     x: 0,    y: 0,    distance: 0,    relativeDistance: 0),
            sample(sessionTime: 222,    lapTime: 22,    x: 1000, y: 0,    distance: 1000, relativeDistance: 0.2),
            sample(sessionTime: 243,    lapTime: 43,    x: 2000, y: 500,  distance: 2000, relativeDistance: 0.4),
            sample(sessionTime: 261,    lapTime: 61,    x: 3000, y: 1000, distance: 3000, relativeDistance: 0.6),
            sample(sessionTime: 278,    lapTime: 78,    x: 4000, y: 500,  distance: 4000, relativeDistance: 0.8),
            sample(sessionTime: 299.0,  lapTime: 99.0,  x: 5000, y: 0,    distance: 5000, relativeDistance: 1.0),
        ],
        officialLapTime: 99.5
    )

    let comparison = try TelemetryComparisonCalculator().compare(reference: reference, compared: compared)

    // Official gap: 99.5 - 100.0 = -0.5 (compared is faster overall)
    #expect(abs(comparison.finalDelta! - (-0.5)) < 0.001)

    // At relDist 0.2: compared is slower (cmp ~22.2 vs ref ~20.1 → delta > 0)
    let earlyDelta = comparison.samples.first(where: { abs($0.relativeDistance - 0.2) < 0.01 })?.delta ?? 0
    #expect(earlyDelta > 0, "Compared should be behind in early sector")

    // At relDist 0.8: compared is ahead (cmp ~78.4 vs ref ~80.4 → delta < 0)
    let lateDelta = comparison.samples.first(where: { abs($0.relativeDistance - 0.8) < 0.01 })?.delta ?? 0
    #expect(lateDelta < 0, "Compared should be ahead in late sector")

    // Delta crossed zero somewhere between 0.2 and 0.8
    let hasCrossing = comparison.samples.contains(where: { $0.relativeDistance > 0.2 && $0.relativeDistance < 0.8 && abs($0.delta) < 1.5 })
    #expect(hasCrossing, "Delta should cross near zero mid-lap")
}
