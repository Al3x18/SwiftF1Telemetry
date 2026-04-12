import Foundation

actor DiskCacheStore: CacheStore {
    private let directory: URL
    private let fileManager: FileManager
    private let maxSizeInBytes: Int?

    init(
        directory: URL,
        fileManager: FileManager = .default,
        maxSizeInBytes: Int? = nil
    ) {
        self.directory = directory
        self.fileManager = fileManager
        self.maxSizeInBytes = maxSizeInBytes
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
            try enforceSizeLimitIfNeeded()
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

    private func enforceSizeLimitIfNeeded() throws {
        guard let maxSizeInBytes else { return }

        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys
        )

        var fileEntries: [(url: URL, modifiedAt: Date, size: Int)] = []
        var totalSize = 0

        for fileURL in contents {
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else { continue }
            let size = values.fileSize ?? 0
            let modifiedAt = values.contentModificationDate ?? .distantPast
            totalSize += size
            fileEntries.append((fileURL, modifiedAt, size))
        }

        guard totalSize > maxSizeInBytes else { return }

        let sortedEntries = fileEntries.sorted { $0.modifiedAt < $1.modifiedAt }
        var currentSize = totalSize

        for entry in sortedEntries where currentSize > maxSizeInBytes {
            try fileManager.removeItem(at: entry.url)
            currentSize -= entry.size
        }
    }
}
