import Foundation
@testable import SwiftF1Telemetry

struct MockBackend: BackendProtocol {
    func availableYears() async throws -> [Int] {
        [2025, 2026]
    }

    func availableEvents(in year: Int) async throws -> [EventDescriptor] {
        [
            EventDescriptor(
                year: year,
                name: "Monza",
                officialName: "\(year) Monza Grand Prix",
                location: "Monza",
                circuitName: "Monza"
            )
        ]
    }

    func availableSessions(in year: Int, event: String) async throws -> [SessionDescriptor] {
        [
            SessionDescriptor(
                year: year,
                eventName: "Monza",
                sessionType: .qualifying,
                name: "Qualifying",
                startDate: nil,
                endDate: nil
            ),
            SessionDescriptor(
                year: year,
                eventName: "Monza",
                sessionType: .race,
                name: "Race",
                startDate: nil,
                endDate: nil
            ),
        ]
    }

    func resolveSession(year: Int, meeting: String, session: SessionType) async throws -> SessionRef {
        SessionRef(
            year: year,
            meeting: meeting,
            sessionType: session,
            backendIdentifier: "mock",
            archivePath: "mock/"
        )
    }

    func fetchSessionMetadata(for session: SessionRef) async throws -> Data {
        try JSONEncoder().encode(
            RawSessionMetadata(
                officialName: "\(session.year) \(session.meeting) Grand Prix",
                circuitName: session.meeting,
                scheduledStart: nil,
                actualStart: nil,
                timezoneIdentifier: "UTC"
            )
        )
    }

    func fetchTimingData(for session: SessionRef) async throws -> Data {
        try JSONEncoder().encode([
            RawLapRecord(driverNumber: "16", lapNumber: 1, startSessionTime: 0, endSessionTime: 90, lapTime: 90, sector1: 30, sector2: 30, sector3: 30, isAccurate: true),
            RawLapRecord(driverNumber: "16", lapNumber: 2, startSessionTime: 90, endSessionTime: 178.4, lapTime: 88.4, sector1: 29.1, sector2: 29.4, sector3: 29.9, isAccurate: true),
            RawLapRecord(driverNumber: "55", lapNumber: 1, startSessionTime: 0, endSessionTime: 91.6, lapTime: 91.6, sector1: 30.2, sector2: 30.4, sector3: 31.0, isAccurate: true),
            RawLapRecord(driverNumber: "55", lapNumber: 2, startSessionTime: 91.6, endSessionTime: 180.8, lapTime: 89.2, sector1: 29.6, sector2: 29.7, sector3: 29.9, isAccurate: true),
        ])
    }

    func fetchCarData(for session: SessionRef) async throws -> Data {
        try JSONEncoder().encode([
            CarSample(driverNumber: "16", sessionTime: 90, date: nil, speed: 120, rpm: 9000, throttle: 0.8, brake: false, drs: 1, gear: 4),
            CarSample(driverNumber: "16", sessionTime: 120, date: nil, speed: 260, rpm: 11800, throttle: 1.0, brake: false, drs: 1, gear: 8),
            CarSample(driverNumber: "16", sessionTime: 150, date: nil, speed: 180, rpm: 9700, throttle: 0.45, brake: true, drs: 0, gear: 5),
            CarSample(driverNumber: "16", sessionTime: 178, date: nil, speed: 140, rpm: 8800, throttle: 0.25, brake: true, drs: 0, gear: 3),
            CarSample(driverNumber: "55", sessionTime: 92, date: nil, speed: 118, rpm: 8900, throttle: 0.76, brake: false, drs: 1, gear: 4),
            CarSample(driverNumber: "55", sessionTime: 122, date: nil, speed: 255, rpm: 11650, throttle: 0.96, brake: false, drs: 1, gear: 8),
            CarSample(driverNumber: "55", sessionTime: 152, date: nil, speed: 176, rpm: 9550, throttle: 0.41, brake: true, drs: 0, gear: 5),
            CarSample(driverNumber: "55", sessionTime: 180, date: nil, speed: 136, rpm: 8650, throttle: 0.20, brake: true, drs: 0, gear: 3),
        ])
    }

    func fetchPositionData(for session: SessionRef) async throws -> Data {
        try JSONEncoder().encode([
            PositionSample(driverNumber: "16", sessionTime: 90, date: nil, x: 0, y: 0, z: 0, status: "OnTrack"),
            PositionSample(driverNumber: "16", sessionTime: 120, date: nil, x: 200, y: 10, z: 0, status: "OnTrack"),
            PositionSample(driverNumber: "16", sessionTime: 150, date: nil, x: 320, y: 40, z: 0, status: "OnTrack"),
            PositionSample(driverNumber: "16", sessionTime: 178, date: nil, x: 410, y: 90, z: 0, status: "OnTrack"),
            PositionSample(driverNumber: "55", sessionTime: 92, date: nil, x: 0, y: 0, z: 0, status: "OnTrack"),
            PositionSample(driverNumber: "55", sessionTime: 122, date: nil, x: 198, y: 12, z: 0, status: "OnTrack"),
            PositionSample(driverNumber: "55", sessionTime: 152, date: nil, x: 318, y: 42, z: 0, status: "OnTrack"),
            PositionSample(driverNumber: "55", sessionTime: 180, date: nil, x: 408, y: 92, z: 0, status: "OnTrack"),
        ])
    }

    func fetchDriverList(for session: SessionRef) async throws -> Data {
        let json = """
        00:00:01.000{"16":{"RacingNumber":"16","FirstName":"Charles","LastName":"Leclerc","FullName":"Charles LECLERC","Tla":"LEC","BroadcastName":"C LECLERC","TeamName":"Ferrari","TeamColour":"E80020","CountryCode":"MON"},"55":{"RacingNumber":"55","FirstName":"Carlos","LastName":"Sainz","FullName":"Carlos SAINZ","Tla":"SAI","BroadcastName":"C SAINZ","TeamName":"Ferrari","TeamColour":"E80020","CountryCode":"ESP"}}
        """
        return Data(json.utf8)
    }
}
