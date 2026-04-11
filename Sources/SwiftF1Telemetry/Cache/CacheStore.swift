import Foundation

protocol CacheStore: Sendable {
    func data(for key: CacheKey) async throws -> Data?
    func save(_ data: Data, for key: CacheKey) async throws
    func removeAll() async throws
}
