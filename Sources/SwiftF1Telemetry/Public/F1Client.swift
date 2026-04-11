import Foundation

public final class F1Client: Sendable {
    public struct Configuration: Sendable {
        public var cacheDirectory: URL
        public var requestTimeout: TimeInterval
        public var maxRetries: Int
        public var userAgent: String

        public static let `default` = Configuration(
            cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("SwiftF1TelemetryCache"),
            requestTimeout: 15,
            maxRetries: 1,
            userAgent: "SwiftF1Telemetry/0.1.0"
        )

        public init(
            cacheDirectory: URL,
            requestTimeout: TimeInterval,
            maxRetries: Int,
            userAgent: String
        ) {
            self.cacheDirectory = cacheDirectory
            self.requestTimeout = requestTimeout
            self.maxRetries = maxRetries
            self.userAgent = userAgent
        }
    }

    private let backend: BackendProtocol
    private let sessionParser = SessionParser()

    public init(configuration: Configuration = .default) {
        let httpClient = URLSessionHTTPClient(
            timeout: configuration.requestTimeout,
            retryPolicy: RetryPolicy(maxRetries: configuration.maxRetries)
        )
        let cacheStore = DiskCacheStore(directory: configuration.cacheDirectory)
        self.backend = DefaultBackend(
            httpClient: httpClient,
            cacheStore: cacheStore,
            configuration: configuration
        )
    }

    init(backend: BackendProtocol) {
        self.backend = backend
    }

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
}
