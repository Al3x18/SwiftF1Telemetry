import Foundation

public enum F1TelemetryError: Error, Sendable {
    case sessionNotFound(year: Int, meeting: String, session: String)
    case invalidResponse(description: String)
    case networkFailure(description: String)
    case parseFailure(dataset: String, description: String)
    case cacheFailure(description: String)
    case noLapsAvailable(driver: String)
    case telemetryUnavailable(driver: String, lap: Int)
    case internalInvariantViolation(description: String)
}
