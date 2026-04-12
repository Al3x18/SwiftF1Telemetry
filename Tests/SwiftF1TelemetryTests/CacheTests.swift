import Foundation
import Testing
@testable import SwiftF1Telemetry

@Test func defaultConfigurationUsesMinimumCacheMode() {
    #expect(F1Client.Configuration.default.cacheMode == .minimum)
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
