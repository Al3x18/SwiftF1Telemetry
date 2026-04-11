import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct URLSessionHTTPClient: HTTPClient, Sendable {
    private let session: URLSession
    private let retryPolicy: RetryPolicy

    init(timeout: TimeInterval, retryPolicy: RetryPolicy) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: configuration)
        self.retryPolicy = retryPolicy
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        var attempt = 0

        while true {
            do {
                var urlRequest = URLRequest(url: request.url, timeoutInterval: request.timeout)
                urlRequest.httpMethod = request.method
                urlRequest.httpBody = request.body
                for (key, value) in request.headers {
                    urlRequest.setValue(value, forHTTPHeaderField: key)
                }

                let (data, response) = try await session.data(for: urlRequest)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw F1TelemetryError.invalidResponse(description: "Missing HTTPURLResponse")
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw F1TelemetryError.networkFailure(
                        description: "HTTP \(httpResponse.statusCode) for \(request.url.absoluteString)"
                    )
                }

                return HTTPResponse(
                    statusCode: httpResponse.statusCode,
                    headers: httpResponse.allHeaderFields.reduce(into: [:]) { partialResult, pair in
                        partialResult[String(describing: pair.key)] = String(describing: pair.value)
                    },
                    body: data
                )
            } catch {
                guard attempt < retryPolicy.maxRetries else {
                    throw F1TelemetryError.networkFailure(description: String(describing: error))
                }
                attempt += 1
                try await Task.sleep(nanoseconds: retryPolicy.delay(forAttempt: attempt))
            }
        }
    }
}
