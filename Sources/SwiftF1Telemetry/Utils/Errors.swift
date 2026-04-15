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
public enum F1TelemetryError: Error, Sendable, Equatable {
    /// The requested season year is not available through archive-backed discovery.
    case yearNotAvailable(year: Int)
    /// The requested event could not be found for the selected season year.
    case eventNotAvailable(year: Int, event: String)
    /// The requested session is not available for the selected event and year.
    case sessionNotAvailable(year: Int, event: String, session: String)
    /// No drivers with lap-backed timing data are available for the selected session.
    case driversNotAvailable(year: Int, event: String, session: String)
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

extension F1TelemetryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .yearNotAvailable(let year):
            return "Year \(year) is not available through archive-backed discovery."
        case .eventNotAvailable(let year, let event):
            return "Event '\(event)' is not available for year \(year)."
        case .sessionNotAvailable(let year, let event, let session):
            return "Session '\(session)' is not available for event '\(event)' in year \(year)."
        case .driversNotAvailable(let year, let event, let session):
            return "No drivers with telemetry-backed lap data are available for event '\(event)' in year \(year) session '\(session)'."
        case .sessionNotFound(let year, let meeting, let session):
            return "Session '\(session)' for event '\(meeting)' in year \(year) was not found."
        case .invalidResponse(let description):
            return description
        case .networkFailure(let description):
            return description
        case .parseFailure(let dataset, let description):
            return "Failed to parse \(dataset): \(description)"
        case .cacheFailure(let description):
            return description
        case .noLapsAvailable(let driver):
            return "No valid laps are available for driver \(driver)."
        case .telemetryUnavailable(let driver, let lap):
            return "Telemetry is unavailable for driver \(driver), lap \(lap)."
        case .internalInvariantViolation(let description):
            return description
        }
    }
}
