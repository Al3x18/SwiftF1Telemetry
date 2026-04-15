import Foundation
import Testing
@testable import SwiftF1Telemetry

@Test func discoveryAPIsExposeYearsEventsSessionsAndDrivers() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())

    let years = try await client.availableYears()
    #expect(years == [2025, 2026])

    let events = try await client.availableEvents(in: 2026)
    #expect(events.count == 1)
    #expect(events.first?.name == "Monza")
    #expect(events.first?.circuitName == "Monza")

    let sessions = try await client.availableSessions(in: 2026, event: "Monza")
    #expect(sessions.map(\.sessionType) == [.qualifying, .race])

    let drivers = try await client.availableDrivers(in: 2026, event: "Monza", session: .qualifying)
    #expect(drivers.map(\.driverNumber) == ["16", "55"])
}

// MARK: - Discovery model field tests

@Test func eventDescriptorExposesAllFields() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let events = try await client.availableEvents(in: 2024)
    let event = try #require(events.first)

    #expect(event.year == 2024)
    #expect(event.name == "Monza")
    #expect(event.officialName == "2024 Monza Grand Prix")
    #expect(event.location == "Monza")
    #expect(event.circuitName == "Monza")
}

@Test func sessionDescriptorExposesAllFields() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let sessions = try await client.availableSessions(in: 2026, event: "Monza")

    let qualifying = try #require(sessions.first(where: { $0.sessionType == .qualifying }))
    #expect(qualifying.year == 2026)
    #expect(qualifying.eventName == "Monza")
    #expect(qualifying.name == "Qualifying")
    #expect(qualifying.startDate == nil)
    #expect(qualifying.endDate == nil)

    let race = try #require(sessions.first(where: { $0.sessionType == .race }))
    #expect(race.year == 2026)
    #expect(race.eventName == "Monza")
    #expect(race.name == "Race")
}

@Test func driverDescriptorExposesDriverNumber() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let drivers = try await client.availableDrivers(in: 2026, event: "Monza", session: .qualifying)

    #expect(drivers.count == 2)
    let first = try #require(drivers.first(where: { $0.driverNumber == "16" }))
    #expect(first.driverNumber == "16")
    let second = try #require(drivers.first(where: { $0.driverNumber == "55" }))
    #expect(second.driverNumber == "55")
}

@Test func eventDescriptorRoundTripsViaCodable() throws {
    let original = EventDescriptor(
        year: 2024,
        name: "Silverstone",
        officialName: "British Grand Prix 2024",
        location: "Silverstone",
        circuitName: "Silverstone"
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(EventDescriptor.self, from: data)

    #expect(decoded == original)
    #expect(decoded.year == 2024)
    #expect(decoded.name == "Silverstone")
    #expect(decoded.officialName == "British Grand Prix 2024")
    #expect(decoded.location == "Silverstone")
    #expect(decoded.circuitName == "Silverstone")
}

@Test func sessionDescriptorRoundTripsViaCodable() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = Date(timeIntervalSince1970: 1_700_007_200)
    let original = SessionDescriptor(
        year: 2024,
        eventName: "Monza",
        sessionType: .race,
        name: "Race",
        startDate: start,
        endDate: end
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(SessionDescriptor.self, from: data)

    #expect(decoded == original)
    #expect(decoded.year == 2024)
    #expect(decoded.eventName == "Monza")
    #expect(decoded.sessionType == .race)
    #expect(decoded.name == "Race")
    #expect(decoded.startDate == start)
    #expect(decoded.endDate == end)
}

@Test func sessionDescriptorHandlesNilDates() throws {
    let original = SessionDescriptor(
        year: 2024,
        eventName: "Monaco",
        sessionType: .qualifying,
        name: "Qualifying",
        startDate: nil,
        endDate: nil
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(SessionDescriptor.self, from: data)

    #expect(decoded == original)
    #expect(decoded.startDate == nil)
    #expect(decoded.endDate == nil)
}

@Test func driverDescriptorRoundTripsViaCodable() throws {
    let original = DriverDescriptor(driverNumber: "44")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(DriverDescriptor.self, from: data)

    #expect(decoded == original)
    #expect(decoded.driverNumber == "44")
}

@Test func availableDriversIncludeNameAndTeam() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let drivers = try await client.availableDrivers(in: 2026, event: "Monza", session: .qualifying)

    let leclerc = try #require(drivers.first(where: { $0.driverNumber == "16" }))
    #expect(leclerc.firstName == "Charles")
    #expect(leclerc.lastName == "Leclerc")
    #expect(leclerc.fullName == "Charles LECLERC")
    #expect(leclerc.abbreviation == "LEC")
    #expect(leclerc.broadcastName == "C LECLERC")
    #expect(leclerc.teamName == "Ferrari")
    #expect(leclerc.teamColour == "E80020")
    #expect(leclerc.countryCode == "MON")

    let sainz = try #require(drivers.first(where: { $0.driverNumber == "55" }))
    #expect(sainz.firstName == "Carlos")
    #expect(sainz.lastName == "Sainz")
    #expect(sainz.abbreviation == "SAI")
    #expect(sainz.teamName == "Ferrari")
}

@Test func resolveDriverByLastName() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let session = try await client.session(year: 2026, meeting: "Monza", session: .qualifying)

    let number = try await session.resolveDriverNumber("Leclerc")
    #expect(number == "16")
}

@Test func resolveDriverByAbbreviation() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let session = try await client.session(year: 2026, meeting: "Monza", session: .qualifying)

    let number = try await session.resolveDriverNumber("SAI")
    #expect(number == "55")
}

@Test func resolveDriverByNumberPassthrough() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let session = try await client.session(year: 2026, meeting: "Monza", session: .qualifying)

    let number = try await session.resolveDriverNumber("16")
    #expect(number == "16")
}

@Test func resolveDriverByFirstName() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let session = try await client.session(year: 2026, meeting: "Monza", session: .qualifying)

    let number = try await session.resolveDriverNumber("Carlos")
    #expect(number == "55")
}

@Test func resolveDriverThrowsForUnknownName() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let session = try await client.session(year: 2026, meeting: "Monza", session: .qualifying)

    await #expect(throws: F1TelemetryError.noLapsAvailable(driver: "Verstappen")) {
        _ = try await session.resolveDriverNumber("Verstappen")
    }
}

@Test func fastestLapAcceptsDriverName() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let session = try await client.session(year: 2026, meeting: "Monza", session: .qualifying)

    let byName = try await session.fastestLap(driver: "Leclerc")
    let byNumber = try await session.fastestLap(driver: "16")
    #expect(byName?.lapNumber == byNumber?.lapNumber)
    #expect(byName?.driverNumber == "16")
}

@Test func compareFastestLapsAcceptsDriverNames() async throws {
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())
    let session = try await client.session(year: 2026, meeting: "Monza", session: .qualifying)

    let comparison = try await session.compareFastestLaps(
        referenceDriver: "Leclerc",
        comparedDriver: "Sainz"
    )
    #expect(comparison.reference.driverNumber == "16")
    #expect(comparison.compared.driverNumber == "55")
    #expect(comparison.samples.isEmpty == false)
}

@Test func driverDescriptorWithAllFieldsRoundTrips() throws {
    let original = DriverDescriptor(
        driverNumber: "16",
        firstName: "Charles",
        lastName: "Leclerc",
        fullName: "Charles LECLERC",
        abbreviation: "LEC",
        broadcastName: "C LECLERC",
        teamName: "Ferrari",
        teamColour: "E80020",
        countryCode: "MON"
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(DriverDescriptor.self, from: data)

    #expect(decoded == original)
    #expect(decoded.firstName == "Charles")
    #expect(decoded.lastName == "Leclerc")
    #expect(decoded.abbreviation == "LEC")
    #expect(decoded.teamName == "Ferrari")
}

@Test func driverDescriptorBackwardCompatibleWithMinimalInit() throws {
    let minimal = DriverDescriptor(driverNumber: "44")
    #expect(minimal.firstName == nil)
    #expect(minimal.lastName == nil)
    #expect(minimal.abbreviation == nil)
    #expect(minimal.teamName == nil)

    let data = try JSONEncoder().encode(minimal)
    let decoded = try JSONDecoder().decode(DriverDescriptor.self, from: data)
    #expect(decoded == minimal)
}

@Test func discoveryModelsAreHashable() {
    let event1 = EventDescriptor(year: 2024, name: "Monza", officialName: "GP Italia", location: "Monza", circuitName: "Monza")
    let event2 = EventDescriptor(year: 2024, name: "Monza", officialName: "GP Italia", location: "Monza", circuitName: "Monza")
    let event3 = EventDescriptor(year: 2025, name: "Monza", officialName: "GP Italia", location: "Monza", circuitName: "Monza")

    #expect(event1 == event2)
    #expect(event1 != event3)
    #expect(Set([event1, event2]).count == 1)
    #expect(Set([event1, event3]).count == 2)

    let driver1 = DriverDescriptor(driverNumber: "16")
    let driver2 = DriverDescriptor(driverNumber: "16")
    let driver3 = DriverDescriptor(driverNumber: "55")

    #expect(driver1 == driver2)
    #expect(driver1 != driver3)
    #expect(Set([driver1, driver2]).count == 1)
    #expect(Set([driver1, driver3]).count == 2)
}

@Test func availableDriversDoesNotRequireSessionMetadata() async throws {
    let client = F1Client(backend: DiscoveryMetadataFailingBackend(), cacheStore: MockCacheStore())

    let drivers = try await client.availableDrivers(in: 2019, event: "Austin", session: .race)

    #expect(drivers.map(\.driverNumber) == ["16", "44"])
}

@Test func discoveryThrowsTypedErrorsForUnavailableInputs() async throws {
    let unavailableClient = F1Client(backend: UnavailableDiscoveryBackend(), cacheStore: MockCacheStore())
    let client = F1Client(backend: MockBackend(), cacheStore: MockCacheStore())

    await #expect(throws: F1TelemetryError.eventNotAvailable(year: 2026, event: "Suzuka")) {
        _ = try await unavailableClient.availableSessions(in: 2026, event: "Suzuka")
    }

    await #expect(throws: F1TelemetryError.sessionNotAvailable(year: 2026, event: "Monza", session: "FP2")) {
        _ = try await client.availableDrivers(in: 2026, event: "Monza", session: .practice2)
    }

    let emptyDriversClient = F1Client(backend: EmptyDriversBackend(), cacheStore: MockCacheStore())
    await #expect(throws: F1TelemetryError.driversNotAvailable(year: 2026, event: "Monza", session: "Q")) {
        _ = try await emptyDriversClient.availableDrivers(in: 2026, event: "Monza", session: .qualifying)
    }
}

private struct DiscoveryMetadataFailingBackend: BackendProtocol {
    func availableYears() async throws -> [Int] { [2019] }

    func availableEvents(in year: Int) async throws -> [EventDescriptor] {
        [
            EventDescriptor(
                year: year,
                name: "Austin",
                officialName: "United States Grand Prix",
                location: "Austin",
                circuitName: "Austin"
            )
        ]
    }

    func availableSessions(in year: Int, event: String) async throws -> [SessionDescriptor] {
        [
            SessionDescriptor(
                year: year,
                eventName: event,
                sessionType: .race,
                name: "Race",
                startDate: nil,
                endDate: nil
            )
        ]
    }

    func resolveSession(year: Int, meeting: String, session: SessionType) async throws -> SessionRef {
        SessionRef(
            year: year,
            meeting: meeting,
            sessionType: session,
            backendIdentifier: "race",
            archivePath: "mock/"
        )
    }

    func fetchSessionMetadata(for session: SessionRef) async throws -> Data {
        throw F1TelemetryError.networkFailure(description: "HTTP 403 for SessionData.json")
    }

    func fetchTimingData(for session: SessionRef) async throws -> Data {
        try JSONEncoder().encode([
            RawLapRecord(driverNumber: "44", lapNumber: 1, startSessionTime: 0, endSessionTime: 92.0, lapTime: 92.0, sector1: nil, sector2: nil, sector3: nil, isAccurate: true),
            RawLapRecord(driverNumber: "16", lapNumber: 1, startSessionTime: 0, endSessionTime: 93.0, lapTime: 93.0, sector1: nil, sector2: nil, sector3: nil, isAccurate: true),
        ])
    }

    func fetchCarData(for session: SessionRef) async throws -> Data { Data() }
    func fetchPositionData(for session: SessionRef) async throws -> Data { Data() }
    func fetchDriverList(for session: SessionRef) async throws -> Data { Data() }
}

private struct EmptyDriversBackend: BackendProtocol {
    func availableYears() async throws -> [Int] { [2026] }

    func availableEvents(in year: Int) async throws -> [EventDescriptor] {
        [
            EventDescriptor(year: year, name: "Monza", officialName: "Monza Grand Prix", location: "Monza", circuitName: "Monza")
        ]
    }

    func availableSessions(in year: Int, event: String) async throws -> [SessionDescriptor] {
        [
            SessionDescriptor(year: year, eventName: event, sessionType: .qualifying, name: "Qualifying", startDate: nil, endDate: nil)
        ]
    }

    func resolveSession(year: Int, meeting: String, session: SessionType) async throws -> SessionRef {
        SessionRef(year: year, meeting: meeting, sessionType: session, backendIdentifier: "q", archivePath: "mock/")
    }

    func fetchSessionMetadata(for session: SessionRef) async throws -> Data { Data() }

    func fetchTimingData(for session: SessionRef) async throws -> Data {
        try JSONEncoder().encode([RawLapRecord]())
    }

    func fetchCarData(for session: SessionRef) async throws -> Data { Data() }
    func fetchPositionData(for session: SessionRef) async throws -> Data { Data() }
    func fetchDriverList(for session: SessionRef) async throws -> Data { Data() }
}

private struct UnavailableDiscoveryBackend: BackendProtocol {
    func availableYears() async throws -> [Int] { [2026] }

    func availableEvents(in year: Int) async throws -> [EventDescriptor] {
        [
            EventDescriptor(year: year, name: "Monza", officialName: "Monza Grand Prix", location: "Monza", circuitName: "Monza")
        ]
    }

    func availableSessions(in year: Int, event: String) async throws -> [SessionDescriptor] {
        guard event == "Monza" else {
            throw F1TelemetryError.eventNotAvailable(year: year, event: event)
        }
        return [
            SessionDescriptor(year: year, eventName: event, sessionType: .qualifying, name: "Qualifying", startDate: nil, endDate: nil)
        ]
    }

    func resolveSession(year: Int, meeting: String, session: SessionType) async throws -> SessionRef {
        throw F1TelemetryError.sessionNotFound(year: year, meeting: meeting, session: session.rawValue)
    }

    func fetchSessionMetadata(for session: SessionRef) async throws -> Data { Data() }
    func fetchTimingData(for session: SessionRef) async throws -> Data { Data() }
    func fetchCarData(for session: SessionRef) async throws -> Data { Data() }
    func fetchPositionData(for session: SessionRef) async throws -> Data { Data() }
    func fetchDriverList(for session: SessionRef) async throws -> Data { Data() }
}
