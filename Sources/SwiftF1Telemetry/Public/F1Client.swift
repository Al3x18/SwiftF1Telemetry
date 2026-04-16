import Foundation

/// The main entry point for fetching F1 telemetry and session data.
///
/// Create a client with the default configuration:
///
/// ```swift
/// let client = F1Client()
/// ```
///
/// Or provide a custom ``Configuration`` to control caching, timeouts, and retries:
///
/// ```swift
/// let config = F1Client.Configuration(
///     cacheDirectory: URL.documentsDirectory.appending(path: "F1Cache"),
///     cacheMode: .large,
///     requestTimeout: 30,
///     maxRetries: 3,
///     userAgent: "MyApp/1.0"
/// )
/// let client = F1Client(configuration: config)
/// ```
public final class F1Client: Sendable {
    private let backend: BackendProtocol
    private let cacheStore: CacheStore
    private let sessionParser = SessionParser()
    private let timingParser = TimingParser()
    private let driverListParser = DriverListParser()

    /// Creates a client using the provided configuration.
    ///
    /// - Parameter configuration: The client configuration. Defaults to ``Configuration/default``.
    public init(configuration: Configuration = .default) {
        let httpClient = URLSessionHTTPClient(
            timeout: configuration.requestTimeout,
            retryPolicy: RetryPolicy(maxRetries: configuration.maxRetries)
        )
        let cacheStore = DiskCacheStore(
            directory: configuration.cacheDirectory,
            maxSizeInBytes: configuration.cacheMode.maxSizeInBytes
        )
        self.cacheStore = cacheStore
        self.backend = DefaultBackend(
            httpClient: httpClient,
            cacheStore: cacheStore,
            configuration: configuration
        )
    }

    // Internal dependency-injection initializer used by tests and module internals.
    // This bypasses automatic construction of network/cache implementations.
    init(backend: BackendProtocol, cacheStore: CacheStore) {
        self.cacheStore = cacheStore
        self.backend = backend
    }

    /// Resolves and loads a session for a given year, meeting, and session type.
    public func session(
        year: Int,
        meeting: String,
        session: SessionType
    ) async throws -> Session {
        let ref = try await backend.resolveSession(year: year, meeting: meeting, session: session)
        let metadataData = try await backend.fetchSessionMetadata(for: ref)
        let metadata = try sessionParser.parseMetadata(from: metadataData)
        return Session(ref: ref, metadata: metadata, backend: backend)
    }

    /// Returns the season years for which the archive-backed telemetry discovery API can resolve data.
    public func availableYears() async throws -> [Int] {
        try await backend.availableYears()
    }

    /// Returns the discoverable events for a specific season year.
    public func availableEvents(in year: Int) async throws -> [EventDescriptor] {
        try await backend.availableEvents(in: year)
    }

    /// Returns the discoverable sessions for a specific event in a season year.
    public func availableSessions(in year: Int, event: String) async throws -> [SessionDescriptor] {
        try await backend.availableSessions(in: year, event: event)
    }

    /// Returns the drivers that have lap-backed telemetry available for the selected session.
    ///
    /// Driver descriptors include name, team, and abbreviation when the archive
    /// provides a `DriverList.jsonStream` for the session.
    public func availableDrivers(in year: Int, event: String, session: SessionType) async throws -> [DriverDescriptor] {
        let resolvedSession = try await discoverableSessionRef(year: year, event: event, session: session)

        let timingData = try await backend.fetchTimingData(for: resolvedSession)
        let uniqueDrivers = Array(Set(try timingParser.parseLaps(from: timingData).map(\.driverNumber))).sorted()
        guard !uniqueDrivers.isEmpty else {
            throw F1TelemetryError.driversNotAvailable(year: year, event: event, session: session.rawValue)
        }

        let infoMap = try? await driverInfoMap(for: resolvedSession)

        return uniqueDrivers.map { number in
            if let info = infoMap?[number] {
                return DriverDescriptor(
                    driverNumber: number,
                    firstName: info.firstName,
                    lastName: info.lastName,
                    fullName: info.fullName,
                    abbreviation: info.abbreviation,
                    broadcastName: info.broadcastName,
                    teamName: info.teamName,
                    teamColour: info.teamColour,
                    countryCode: info.countryCode
                )
            }
            return DriverDescriptor(driverNumber: number)
        }
    }

    /// Removes all cached raw payloads from the configured cache directory.
    public func clearCache() async throws {
        try await cacheStore.removeAll()
    }

    /// Returns the current on-disk cache size in megabytes.
    ///
    /// ```swift
    /// let sizeMB = try await client.cacheSizeInMB()
    /// print("Cache: \(String(format: "%.1f", sizeMB)) MB")
    /// ```
    public func cacheSizeInMB() async throws -> Double {
        Double(try await cacheStore.totalSizeInBytes()) / (1_024 * 1_024)
    }

    private func driverInfoMap(for session: SessionRef) async throws -> [String: RawDriverEntry] {
        let data = try await backend.fetchDriverList(for: session)
        let entries = try driverListParser.parse(from: data)
        return Dictionary(entries.map { ($0.racingNumber, $0) }, uniquingKeysWith: { _, new in new })
    }

    private func discoverableSessionRef(year: Int, event: String, session: SessionType) async throws -> SessionRef {
        let availableSessions = try await backend.availableSessions(in: year, event: event)
        guard availableSessions.contains(where: { $0.sessionType == session }) else {
            throw F1TelemetryError.sessionNotAvailable(year: year, event: event, session: session.rawValue)
        }

        do {
            return try await backend.resolveSession(year: year, meeting: event, session: session)
        } catch let error as F1TelemetryError {
            switch error {
            case .sessionNotFound:
                throw F1TelemetryError.sessionNotAvailable(year: year, event: event, session: session.rawValue)
            default:
                throw error
            }
        }
    }
}
