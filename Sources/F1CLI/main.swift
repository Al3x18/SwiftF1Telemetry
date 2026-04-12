import Foundation
import SwiftF1Telemetry

@main
struct F1CLI {
    static func main() async {
        let arguments = CommandLine.arguments
        guard arguments.count >= 4 else {
            print("Usage: swift run f1-cli <year> <meeting> <session> [driver]")
            print("Example: swift run f1-cli 2026 \"Monza\" Q 16")
            return
        }

        let year = Int(arguments[1]) ?? 2026
        let meeting = arguments[2]
        let sessionCode = arguments[3]
        let driver = arguments.count > 4 ? arguments[4] : "16"

        guard let sessionType = SessionType(rawValue: sessionCode) else {
            print("Unknown session code '\(sessionCode)'. Use FP1, FP2, FP3, SQ, S, Q, or R.")
            return
        }
        
        var configuration = F1Client.Configuration.default
        configuration.cacheMode = .medium

        let client = F1Client(configuration: configuration)

        do {
            let session = try await client.session(year: year, meeting: meeting, session: sessionType)
            print("Session: \(session.metadata.officialName)")
            print("Circuit: \(session.metadata.circuitName)")

            let laps = try await session.laps()
            print("Loaded laps: \(laps.count)")

            if let lap = try await session.fastestLap(driver: driver) {
                print("Fastest lap for #\(driver): lap \(lap.lapNumber) in \(TimeUtils.format(seconds: lap.lapTime))")
                let telemetry = try await session.telemetry(for: lap)
                print("Telemetry samples: \(telemetry.samples.count)")
                if let first = telemetry.speedSeriesByDistance().first {
                    print(String(format: "First speed point: distance %.1f m, speed %.1f km/h", first.x, first.y))
                }
            } else {
                print("No fastest lap available for #\(driver).")
            }
        } catch {
            print("Failed to load session data: \(error)")
        }
    }
}
