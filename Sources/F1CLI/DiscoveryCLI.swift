import Foundation
import SwiftF1Telemetry

enum DiscoveryCLI {
    static func run(arguments: [String], client: F1Client) async throws -> Bool {
        guard let command = arguments.dropFirst().first,
              command == "discover" || command == "browse" else {
            return false
        }

        switch arguments.count {
        case 2:
            try await printAvailableYears(client: client)
        case 3:
            let year = try await parseAvailableYear(arguments[2], client: client)
            try await printAvailableEvents(in: year, client: client)
        case 4:
            let year = try await parseAvailableYear(arguments[2], client: client)
            let event = arguments[3]
            try await printAvailableSessions(in: year, event: event, client: client)
        default:
            let year = try await parseAvailableYear(arguments[2], client: client)
            let event = arguments[3]
            let sessionType = try parseSessionType(arguments[4])
            try await printAvailableDrivers(in: year, event: event, session: sessionType, client: client)
        }

        return true
    }

    private static func printAvailableYears(client: F1Client) async throws {
        let years = try await client.availableYears()
        print("Available years:")
        years.forEach { print("- \($0)") }
    }

    private static func printAvailableEvents(in year: Int, client: F1Client) async throws {
        let events = try await client.availableEvents(in: year)
        print("Available events for \(year):")
        events.forEach { event in
            print("- \(event.name) | \(event.circuitName) | \(event.location)")
        }
    }

    private static func printAvailableSessions(in year: Int, event: String, client: F1Client) async throws {
        let sessions = try await client.availableSessions(in: year, event: event)
        print("Available sessions for \(event) \(year):")
        sessions.forEach { session in
            print("- \(session.sessionType.rawValue) | \(session.name)")
        }
    }

    private static func printAvailableDrivers(
        in year: Int,
        event: String,
        session: SessionType,
        client: F1Client
    ) async throws {
        let drivers = try await client.availableDrivers(in: year, event: event, session: session)
        print("Available drivers for \(event) \(year) \(session.rawValue):")
        drivers.forEach { driver in
            var line = "- #\(driver.driverNumber)"
            if let abbr = driver.abbreviation { line += " \(abbr)" }
            if let first = driver.firstName, let last = driver.lastName {
                line += " — \(first) \(last)"
            }
            if let team = driver.teamName { line += " (\(team))" }
            print(line)
        }
    }

    private static func parseAvailableYear(_ rawYear: String, client: F1Client) async throws -> Int {
        guard let year = Int(rawYear) else {
            throw CLIError.invalidYear(rawYear)
        }

        let years = try await client.availableYears()
        guard years.contains(year) else {
            throw F1TelemetryError.yearNotAvailable(year: year)
        }
        return year
    }

    private static func parseSessionType(_ rawValue: String) throws -> SessionType {
        guard let sessionType = SessionType(rawValue: rawValue) else {
            throw CLIError.invalidSessionCode(rawValue)
        }
        return sessionType
    }
}

enum CLIError: LocalizedError {
    case invalidYear(String)
    case invalidSessionCode(String)

    var errorDescription: String? {
        switch self {
        case .invalidYear(let value):
            return "Invalid year '\(value)'."
        case .invalidSessionCode(let value):
            return "Unknown session code '\(value)'. Use FP1, FP2, FP3, SQ, S, Q, or R."
        }
    }
}
