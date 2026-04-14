import Foundation

/// Errors thrown by SwiftF1Telemetry operations.
///
/// Handle specific cases to provide meaningful feedback:
///
/// ```swift
/// do {
///     let session = try await client.session(year: 2024, meeting: "Monza", session: .race)
///     let telemetry = try await session.telemetry(for: lap)
/// } catch let error as F1TelemetryError {
///     switch error {
///     case .sessionNotFound:
///         print("Session not found in the archive.")
///     case .telemetryUnavailable(let driver, let lap):
///         print("No telemetry for driver \(driver), lap \(lap).")
///     default:
///         print("Error: \(error)")
///     }
/// }
/// ```
public enum F1TelemetryError: Error, Sendable {
    /// The requested session could not be resolved in the archive.
    case sessionNotFound(year: Int, meeting: String, session: String)
    /// The upstream server returned an unexpected or malformed response.
    case invalidResponse(description: String)
    /// A network request failed after all retry attempts.
    case networkFailure(description: String)
    /// Raw data could not be parsed into the expected model.
    case parseFailure(dataset: String, description: String)
    /// A disk-cache read or write operation failed.
    case cacheFailure(description: String)
    /// No valid laps were found for the specified driver.
    case noLapsAvailable(driver: String)
    /// Telemetry data is not available for the specified driver and lap.
    case telemetryUnavailable(driver: String, lap: Int)
    /// An internal consistency check failed — likely a library bug.
    case internalInvariantViolation(description: String)
}
