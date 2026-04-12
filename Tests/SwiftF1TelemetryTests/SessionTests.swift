import Testing
@testable import SwiftF1Telemetry

@Test func sessionTypeRawValuesAndFastestLapSelection() async throws {
    #expect(SessionType.qualifying.rawValue == "Q")

    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let session = try await client.session(year: 2026, meeting: "Monza", session: .qualifying)
    let lap = try await session.fastestLap(driver: "16")

    #expect(lap?.lapNumber == 2)
    #expect(lap?.lapTime == 88.4)
}
