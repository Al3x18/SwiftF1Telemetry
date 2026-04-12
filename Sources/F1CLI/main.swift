import Foundation
import SwiftF1Telemetry

@main
struct F1CLI {
    static func main() async {
        let arguments: [String] = CommandLine.arguments

        if arguments.count >= 2 {
            let first: String = arguments[1]
            if first == "clear-cache" || first == "--clear-cache" {
                var configuration: F1Client.Configuration = F1Client.Configuration.default
                configuration.cacheMode = .medium
                let client: F1Client = F1Client(configuration: configuration)
                do {
                    try await client.clearCache()
                    print("Cache cleared.")
                } catch {
                    print("Failed to clear cache: \(error)")
                }
                return
            }
        }

        guard arguments.count >= 4 else {
            print("Usage: swift run f1-cli <year> <meeting> <session> [driver]")
            print("       swift run f1-cli clear-cache")
            print("Example: swift run f1-cli 2026 \"Monza\" Q 16")
            return
        }

        let year: Int = Int(arguments[1]) ?? 2026
        let meeting: String = arguments[2]
        let sessionCode: String = arguments[3]
        let driver: String = arguments.count > 4 ? arguments[4] : "16"

        guard let sessionType: SessionType = SessionType(rawValue: sessionCode) else {
            print("Unknown session code '\(sessionCode)'. Use FP1, FP2, FP3, SQ, S, Q, or R.")
            return
        }
        
        var configuration: F1Client.Configuration = F1Client.Configuration.default
        configuration.cacheMode = .medium

        let client: F1Client = F1Client(configuration: configuration)

        do {
            let session: Session = try await client.session(year: year, meeting: meeting, session: sessionType)
            print("Session: \(session.metadata.officialName)")
            print("Circuit: \(session.metadata.circuitName)")

            let laps: [Lap] = try await session.laps()
            print("Loaded laps: \(laps.count)")

            if let lap: Lap = try await session.fastestLap(driver: driver) {
                print("Fastest lap for #\(driver): lap \(lap.lapNumber) in \(TimeUtils.format(seconds: lap.lapTime))")
                let telemetry: TelemetryTrace = try await session.telemetry(for: lap)
                print("Telemetry samples: \(telemetry.samples.count)")
                if let first: ChartPoint<Double> = telemetry.speedSeriesByDistance().first {
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
