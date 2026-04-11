import Foundation

protocol BackendProtocol: Sendable {
    func resolveSession(
        year: Int,
        meeting: String,
        session: SessionType
    ) async throws -> SessionRef

    func fetchSessionMetadata(for session: SessionRef) async throws -> Data
    func fetchTimingData(for session: SessionRef) async throws -> Data
    func fetchCarData(for session: SessionRef) async throws -> Data
    func fetchPositionData(for session: SessionRef) async throws -> Data
}
