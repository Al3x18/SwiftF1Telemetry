import Foundation
import Testing
@testable import SwiftF1Telemetry

@Test func defaultConfigurationUsesMinimumCacheMode() {
    #expect(F1Client.Configuration.default.cacheMode == .minimum)
    #expect(F1Client.Configuration.default.cacheDirectory.lastPathComponent == "SwiftF1Telemetry")
}

@Test func cacheModeUnlimitedHasNoSizeLimit() {
    #expect(F1Client.Configuration.CacheMode.unlimited.maxSizeInBytes == nil)
}

@Test func cacheModeNoCacheReportsZeroBytes() {
    #expect(F1Client.Configuration.CacheMode.noCache.maxSizeInBytes == 0)
}

@Test func cacheModeBoundedModesExposeExpectedLimits() {
    #expect(F1Client.Configuration.CacheMode.minimum.maxSizeInBytes == 50 * 1_024 * 1_024)
    #expect(F1Client.Configuration.CacheMode.medium.maxSizeInBytes == 100 * 1_024 * 1_024)
    #expect(F1Client.Configuration.CacheMode.large.maxSizeInBytes == 200 * 1_024 * 1_024)
    #expect(F1Client.Configuration.CacheMode.extraLarge.maxSizeInBytes == 400 * 1_024 * 1_024)
}

@Test func diskCacheWithZeroLimitEvictsAnySavedFile() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftF1TelemetryNoCacheTests-\(UUID().uuidString)")

    let store = DiskCacheStore(directory: directory, maxSizeInBytes: 0)
    let session = SessionRef(
        year: 2024,
        meeting: "Monza",
        sessionType: .qualifying,
        backendIdentifier: "test",
        archivePath: "test/"
    )
    let key = CacheKey(session: session, dataset: "payload")

    try await store.save(Data("payload".utf8), for: key)

    #expect(try await store.data(for: key) == nil)
    #expect(try await store.totalSizeInBytes() == 0)

    try await store.removeAll()
}

@Test func cacheModeNoCacheBypassesReadAndWrite() async throws {
    let year = 2023
    let indexJSON = """
    {
      "Year": 2023,
      "Meetings": [
        {
          "Name": "Italian Grand Prix",
          "OfficialName": "FORMULA 1 ITALIAN GRAND PRIX 2023",
          "Location": "Monza",
          "Circuit": { "ShortName": "Monza" },
          "Sessions": []
        }
      ]
    }
    """
    let url = URL(string: "https://livetiming.formula1.com/static/\(year)/Index.json")!
    let httpClient = CountingHTTPClient(
        responses: [
            url: Data(indexJSON.utf8)
        ]
    )
    let cacheStore = CountingCacheStore()
    let configuration = F1Client.Configuration(
        cacheDirectory: FileManager.default.temporaryDirectory,
        cacheMode: .noCache,
        requestTimeout: 15,
        maxRetries: 1,
        userAgent: "SwiftF1TelemetryTests"
    )
    let backend = DefaultBackend(httpClient: httpClient, cacheStore: cacheStore, configuration: configuration)

    _ = try await backend.availableEvents(in: year)
    _ = try await backend.availableEvents(in: year)

    let cacheStats = await cacheStore.stats()
    #expect(cacheStats.dataCalls == 0)
    #expect(cacheStats.saveCalls == 0)
    #expect(await httpClient.requestCount(for: url) == 2)
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

private actor CountingCacheStore: CacheStore {
    private var dataCalls = 0
    private var saveCalls = 0

    func data(for _: CacheKey) async throws -> Data? {
        dataCalls += 1
        return nil
    }

    func save(_: Data, for _: CacheKey) async throws {
        saveCalls += 1
    }

    func removeAll() async throws {}

    func totalSizeInBytes() async throws -> Int { 0 }

    func stats() -> (dataCalls: Int, saveCalls: Int) {
        (dataCalls, saveCalls)
    }
}

private actor CountingHTTPClient: HTTPClient {
    private let responses: [URL: Data]
    private var counts: [URL: Int] = [:]

    init(responses: [URL: Data]) {
        self.responses = responses
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        counts[request.url, default: 0] += 1
        guard let data = responses[request.url] else {
            throw F1TelemetryError.networkFailure(description: "No stub response for \(request.url.absoluteString)")
        }
        return HTTPResponse(statusCode: 200, headers: [:], body: data)
    }

    func requestCount(for url: URL) -> Int {
        counts[url, default: 0]
    }
}
