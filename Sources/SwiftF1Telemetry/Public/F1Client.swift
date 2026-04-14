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
    /// Configures networking, caching, and retry behavior for an ``F1Client``.
    public struct Configuration: Sendable {
        /// Controls how much disk space the built-in raw payload cache may use.
        public enum CacheMode: Sendable {
            /// Disables on-disk caching entirely.
            case disabled
            /// Keeps up to 50 MB of cached data on disk.
            case minimum
            /// Keeps up to 100 MB of cached data on disk.
            case medium
            /// Keeps up to 200 MB of cached data on disk.
            case large
            /// Keeps up to 400 MB of cached data on disk.
            case extraLarge

            var maxSizeInBytes: Int? {
                switch self {
                case .disabled:
                    return nil
                case .minimum:
                    return 50 * 1_024 * 1_024
                case .medium:
                    return 100 * 1_024 * 1_024
                case .large:
                    return 200 * 1_024 * 1_024
                case .extraLarge:
                    return 400 * 1_024 * 1_024
                }
            }
        }

        /// Directory where raw upstream payloads are cached on disk.
        public var cacheDirectory: URL
        /// Cache retention profile used by the built-in disk cache.
        public var cacheMode: CacheMode
        /// Request timeout, in seconds, for archive and telemetry HTTP calls.
        public var requestTimeout: TimeInterval
        /// Maximum number of retry attempts for failed HTTP requests.
        public var maxRetries: Int
        /// Custom HTTP user agent sent with upstream requests.
        public var userAgent: String

        /// The default configuration used when calling `F1Client()` with no arguments.
        public static let `default` = Configuration(
            cacheDirectory: PlatformPaths.defaultCacheDirectory(named: "SwiftF1Telemetry"),
            cacheMode: .minimum,
            requestTimeout: 15,
            maxRetries: 1,
            userAgent: "SwiftF1Telemetry/\(SwiftF1TelemetryVersion.current)"
        )

        /// Creates a custom client configuration.
        ///
        /// - Parameters:
        ///   - cacheDirectory: The directory where raw payloads are stored on disk.
        ///   - cacheMode: The disk-space retention profile for the cache.
        ///   - requestTimeout: HTTP request timeout in seconds.
        ///   - maxRetries: How many times a failed request is retried before throwing.
        ///   - userAgent: The `User-Agent` header sent with every HTTP request.
        public init(
            cacheDirectory: URL,
            cacheMode: CacheMode,
            requestTimeout: TimeInterval,
            maxRetries: Int,
            userAgent: String
        ) {
            self.cacheDirectory = cacheDirectory
            self.cacheMode = cacheMode
            self.requestTimeout = requestTimeout
            self.maxRetries = maxRetries
            self.userAgent = userAgent
        }
    }

    private let backend: BackendProtocol
    private let cacheStore: CacheStore
    private let sessionParser = SessionParser()

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
}
