import Foundation

extension F1Client {
    /// Configures networking, caching, and retry behavior for an ``F1Client``.
    public struct Configuration: Sendable {
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

     /// Controls how much disk space the built-in raw payload cache may use.
        public enum CacheMode: Sendable {
            /// Disables on-disk caching entirely.
            case noCache
            /// Keeps up to 50 MB of cached data on disk.
            case minimum
            /// Keeps up to 100 MB of cached data on disk.
            case medium
            /// Keeps up to 200 MB of cached data on disk.
            case large
            /// Keeps up to 400 MB of cached data on disk.
            case extraLarge
            /// Keeps caching enabled with no size limit.
            case unlimited

            var maxSizeInBytes: Int? {
                switch self {
                case .noCache:
                    // Cache is fully bypassed at the backend level; report 0 bytes
                    // so any accidental direct use of the store evicts everything.
                    return 0
                case .minimum:
                    return 50 * 1_024 * 1_024
                case .medium:
                    return 100 * 1_024 * 1_024
                case .large:
                    return 200 * 1_024 * 1_024
                case .extraLarge:
                    return 400 * 1_024 * 1_024
                case .unlimited:
                    return nil
                }
            }
        }
}
