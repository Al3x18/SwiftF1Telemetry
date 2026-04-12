import Foundation
@testable import SwiftF1Telemetry

actor MockCacheStore: CacheStore {
    private var storage: [CacheKey: Data] = [:]

    func data(for key: CacheKey) async throws -> Data? {
        storage[key]
    }

    func save(_ data: Data, for key: CacheKey) async throws {
        storage[key] = data
    }

    func removeAll() async throws {
        storage.removeAll()
    }
}
