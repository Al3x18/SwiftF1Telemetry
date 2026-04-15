import Foundation
import SwiftF1Telemetry

enum F1CLIRunner {
    static func run(arguments: [String]) async {
        let client = makeClient()

        if await handleClearCacheIfNeeded(arguments: arguments, client: client) {
            return
        }

        do {
            if try await DiscoveryCLI.run(arguments: arguments, client: client) {
                return
            }
        } catch {
            print("Discovery failed: \(rendered(error))")
            return
        }

        guard arguments.count >= 4 else {
            printUsage()
            return
        }

        do {
            try await runTelemetry(arguments: arguments, client: client)
        } catch {
            print("Failed to load session data: \(rendered(error))")
        }
    }

    private static func makeClient() -> F1Client {
        var configuration = F1Client.Configuration.default
        configuration.cacheMode = .medium
        return F1Client(configuration: configuration)
    }

    private static func handleClearCacheIfNeeded(arguments: [String], client: F1Client) async -> Bool {
        guard let command = arguments.dropFirst().first,
              command == "clear-cache" || command == "--clear-cache" else {
            return false
        }

        do {
            try await client.clearCache()
            print("Cache cleared.")
        } catch {
            print("Failed to clear cache: \(rendered(error))")
        }
        return true
    }

    private static func runTelemetry(arguments: [String], client: F1Client) async throws {
        let year = Int(arguments[1]) ?? 2026
        let meeting = arguments[2]
        let sessionCode = arguments[3]
        let driver = arguments.count > 4 ? arguments[4] : "16"
        let compareDriver = arguments.count > 5 ? arguments[5] : nil

        guard let sessionType = SessionType(rawValue: sessionCode) else {
            throw CLIError.invalidSessionCode(sessionCode)
        }

        let session = try await client.session(year: year, meeting: meeting, session: sessionType)
        print("Session: \(session.metadata.officialName)")
        print("Circuit: \(session.metadata.circuitName)")

        let laps = try await session.laps()
        print("Loaded laps: \(laps.count)")

        guard let lap = try await session.fastestLap(driver: driver) else {
            print("No fastest lap available for #\(driver).")
            return
        }

        print("Fastest lap for #\(driver): lap \(lap.lapNumber) in \(TimeUtils.format(seconds: lap.lapTime))")

        let telemetry = try await session.telemetry(for: lap)
        print("Telemetry samples: \(telemetry.samples.count)")

        if let first = telemetry.speedSeriesByDistance().first {
            print(String(format: "First speed point: distance %.1f m, speed %.1f km/h", first.x, first.y))
        }

        guard let compareDriver else { return }

        print("\n--- Comparison: #\(driver) vs #\(compareDriver) ---")
        let comparison = try await session.compareFastestLaps(
            referenceDriver: driver,
            comparedDriver: compareDriver
        )

        print("Reference: #\(comparison.reference.driverNumber) lap \(comparison.reference.lapNumber)")
        print("Compared:  #\(comparison.compared.driverNumber) lap \(comparison.compared.lapNumber)")
        print("Aligned samples: \(comparison.samples.count)")

        if let delta = comparison.finalDelta {
            let sign = delta >= 0 ? "+" : ""
            print(String(format: "Final delta: %@%.3fs (%@ is %@)",
                         sign, delta,
                         compareDriver,
                         delta >= 0 ? "slower" : "faster"))
        }

        let deltaSeries = comparison.deltaSeriesByDistance()
        if let first = deltaSeries.first, let last = deltaSeries.last {
            print(String(format: "Delta range: %.3fs at %.0fm → %.3fs at %.0fm",
                         first.y, first.x, last.y, last.x))
        }

        let refSpeed = comparison.referenceSpeedSeriesByDistance()
        let cmpSpeed = comparison.comparedSpeedSeriesByDistance()
        print("Speed points: ref=\(refSpeed.count), cmp=\(cmpSpeed.count)")
    }

    private static func printUsage() {
        print("Discovery:")
        print("  swift run f1-cli discover")
        print("  swift run f1-cli discover <year>")
        print("  swift run f1-cli discover <year> <event>")
        print("  swift run f1-cli discover <year> <event> <session>")
        print("")
        print("Telemetry:")
        print("Usage: swift run f1-cli <year> <meeting> <session> [driver] [compare-driver]")
        print("       swift run f1-cli clear-cache")
        print("Driver can be a number, last name, or abbreviation:")
        print("  swift run f1-cli 2024 Monza Q 16")
        print("  swift run f1-cli 2024 Monza Q Leclerc")
        print("  swift run f1-cli 2024 Monza Q LEC")
        print("Compare: swift run f1-cli 2024 Monza Q Leclerc Sainz")
    }

    private static func rendered(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        return String(describing: error)
    }
}
