import Foundation

actor DiskCacheStore: CacheStore {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func data(for key: CacheKey) async throws -> Data? {
        try ensureDirectoryExists()
        let url = directory.appendingPathComponent(key.filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw F1TelemetryError.cacheFailure(description: "Read failed for \(url.path): \(error)")
        }
    }

    func save(_ data: Data, for key: CacheKey) async throws {
        try ensureDirectoryExists()
        let url = directory.appendingPathComponent(key.filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw F1TelemetryError.cacheFailure(description: "Write failed for \(url.path): \(error)")
        }
    }

    func removeAll() async throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            throw F1TelemetryError.cacheFailure(description: "Clear cache failed: \(error)")
        }
    }

    private func ensureDirectoryExists() throws {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw F1TelemetryError.cacheFailure(description: "Create cache directory failed: \(error)")
        }
    }
}
