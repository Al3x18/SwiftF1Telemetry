import Foundation

protocol BackendProtocol: Sendable {
    func availableYears() async throws -> [Int]
    func availableEvents(in year: Int) async throws -> [EventDescriptor]
    func availableSessions(in year: Int, event: String) async throws -> [SessionDescriptor]

    func resolveSession(
        year: Int,
        meeting: String,
        session: SessionType
    ) async throws -> SessionRef

    func fetchSessionMetadata(for session: SessionRef) async throws -> Data
    func fetchTimingData(for session: SessionRef) async throws -> Data
    func fetchCarData(for session: SessionRef) async throws -> Data
    func fetchPositionData(for session: SessionRef) async throws -> Data
    func fetchDriverList(for session: SessionRef) async throws -> Data
}
