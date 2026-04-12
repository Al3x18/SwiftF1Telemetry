import Foundation
import Testing
@testable import SwiftF1Telemetry

@Test func defaultConfigurationUsesMinimumCacheMode() {
    #expect(F1Client.Configuration.default.cacheMode == .minimum)
    #expect(F1Client.Configuration.default.cacheDirectory.lastPathComponent == "SwiftF1Telemetry")
}

@Test func diskCacheEvictsOldFilesWhenLimitIsExceeded() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftF1TelemetryCacheTests-\(UUID().uuidString)")

    let store = DiskCacheStore(directory: directory, maxSizeInBytes: 15)
    let session = SessionRef(
        year: 2024,
        meeting: "Monza",
        sessionType: .qualifying,
        backendIdentifier: "test",
        archivePath: "test/"
    )

    let firstKey = CacheKey(session: session, dataset: "first")
    let secondKey = CacheKey(session: session, dataset: "second")

    try await store.save(Data("1234567890".utf8), for: firstKey)
    try await Task.sleep(nanoseconds: 5_000_000)
    try await store.save(Data("abcdefghij".utf8), for: secondKey)

    let first = try await store.data(for: firstKey)
    let second = try await store.data(for: secondKey)

    #expect(first == nil)
    #expect(second != nil)

    try await store.removeAll()
}

@Test func clientCanClearCachePublicly() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftF1TelemetryClientCacheTests-\(UUID().uuidString)")

    let configuration = F1Client.Configuration(
        cacheDirectory: directory,
        cacheMode: .minimum,
        requestTimeout: 15,
        maxRetries: 1,
        userAgent: "SwiftF1TelemetryTests"
    )

    let client = F1Client(configuration: configuration)
    _ = try await client.session(year: 2024, meeting: "Monza", session: .qualifying)

    let before = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    #expect(before.isEmpty == false)

    try await client.clearCache()

    let after = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    #expect(after.isEmpty)
}

@Test func publicTelemetryModelsSupportCodableRoundTrip() throws {
    let trace = TelemetryTrace(
        driverNumber: "16",
        lapNumber: 20,
        samples: [
            TelemetrySample(
                sessionTime: 123.4,
                lapTime: 12.3,
                speed: 321,
                rpm: 11200,
                throttle: 0.98,
                brake: false,
                drs: 12,
                gear: 8,
                x: 100,
                y: 200,
                z: 5,
                status: "OnTrack",
                distance: 5432.1,
                relativeDistance: 0.94,
                source: .merged
            )
        ]
    )

    let encoded = try JSONEncoder().encode(trace)
    let decoded = try JSONDecoder().decode(TelemetryTrace.self, from: encoded)

    #expect(decoded.driverNumber == trace.driverNumber)
    #expect(decoded.lapNumber == trace.lapNumber)
    #expect(decoded.samples == trace.samples)
}

@Test func publicSessionModelsSupportCodableRoundTrip() throws {
    let lap = Lap(
        driverNumber: "55",
        lapNumber: 14,
        startSessionTime: 400,
        endSessionTime: 482.4,
        lapTime: 82.4,
        sector1: 26.1,
        sector2: 28.0,
        sector3: 28.3,
        isAccurate: true
    )
    let sessionRef = SessionRef(
        year: 2024,
        meeting: "Monza",
        sessionType: .qualifying,
        backendIdentifier: "archive",
        archivePath: "2024/monza/q"
    )
    let metadata = SessionMetadata(
        officialName: "Italian Grand Prix - Qualifying",
        circuitName: "Monza",
        scheduledStart: nil,
        actualStart: nil,
        timezoneIdentifier: "Europe/Rome"
    )

    let lapData = try JSONEncoder().encode(lap)
    let sessionRefData = try JSONEncoder().encode(sessionRef)
    let metadataData = try JSONEncoder().encode(metadata)

    #expect(try JSONDecoder().decode(Lap.self, from: lapData) == lap)
    #expect(try JSONDecoder().decode(SessionRef.self, from: sessionRefData) == sessionRef)
    #expect(try JSONDecoder().decode(SessionMetadata.self, from: metadataData) == metadata)
}
