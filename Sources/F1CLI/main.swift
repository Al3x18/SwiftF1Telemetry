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
            print("Usage: swift run f1-cli <year> <meeting> <session> [driver] [compare-driver]")
            print("       swift run f1-cli clear-cache")
            print("Example: swift run f1-cli 2026 \"Monza\" Q 16")
            print("Compare: swift run f1-cli 2026 \"Monza\" Q 16 55")
            return
        }

        let year: Int = Int(arguments[1]) ?? 2026
        let meeting: String = arguments[2]
        let sessionCode: String = arguments[3]
        let driver: String = arguments.count > 4 ? arguments[4] : "16"
        let compareDriver: String? = arguments.count > 5 ? arguments[5] : nil

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

                if let compareDriver: String {
                    print("\n--- Comparison: #\(driver) vs #\(compareDriver) ---")
                    let comparison: TelemetryComparison = try await session.compareFastestLaps(
                        referenceDriver: driver,
                        comparedDriver: compareDriver
                    )

                    print("Reference: #\(comparison.reference.driverNumber) lap \(comparison.reference.lapNumber)")
                    print("Compared:  #\(comparison.compared.driverNumber) lap \(comparison.compared.lapNumber)")
                    print("Aligned samples: \(comparison.samples.count)")

                    if let delta: TimeInterval = comparison.finalDelta {
                        let sign: String = delta >= 0 ? "+" : ""
                        print(String(format: "Final delta: %@%.3fs (%@ is %@)",
                                     sign, delta,
                                     compareDriver,
                                     delta >= 0 ? "slower" : "faster"))
                    }

                    let deltaSeries: [ChartPoint<Double>] = comparison.deltaSeriesByDistance()
                    if let first: ChartPoint<Double> = deltaSeries.first,
                       let last: ChartPoint<Double> = deltaSeries.last {
                        print(String(format: "Delta range: %.3fs at %.0fm → %.3fs at %.0fm",
                                     first.y, first.x, last.y, last.x))
                    }

                    let refSpeed: [ChartPoint<Double>] = comparison.referenceSpeedSeriesByDistance()
                    let cmpSpeed: [ChartPoint<Double>] = comparison.comparedSpeedSeriesByDistance()
                    print("Speed points: ref=\(refSpeed.count), cmp=\(cmpSpeed.count)")
                }
            } else {
                print("No fastest lap available for #\(driver).")
            }
        } catch {
            print("Failed to load session data: \(error)")
        }
    }
}
