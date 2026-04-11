import Foundation

struct RawLapRecord: Sendable, Codable, Hashable {
    let driverNumber: String
    let lapNumber: Int
    let startSessionTime: TimeInterval
    let endSessionTime: TimeInterval
    let lapTime: TimeInterval?
    let sector1: TimeInterval?
    let sector2: TimeInterval?
    let sector3: TimeInterval?
    let isAccurate: Bool

    func toPublicLap() -> Lap {
        Lap(
            driverNumber: driverNumber,
            lapNumber: lapNumber,
            startSessionTime: startSessionTime,
            endSessionTime: endSessionTime,
            lapTime: lapTime,
            sector1: sector1,
            sector2: sector2,
            sector3: sector3,
            isAccurate: isAccurate
        )
    }
}
