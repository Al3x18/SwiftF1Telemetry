import Foundation

public struct Lap: Sendable, Hashable, Codable {
    public let driverNumber: String
    public let lapNumber: Int
    public let startSessionTime: TimeInterval
    public let endSessionTime: TimeInterval
    public let lapTime: TimeInterval?
    public let sector1: TimeInterval?
    public let sector2: TimeInterval?
    public let sector3: TimeInterval?
    public let isAccurate: Bool

    public init(
        driverNumber: String,
        lapNumber: Int,
        startSessionTime: TimeInterval,
        endSessionTime: TimeInterval,
        lapTime: TimeInterval?,
        sector1: TimeInterval?,
        sector2: TimeInterval?,
        sector3: TimeInterval?,
        isAccurate: Bool
    ) {
        self.driverNumber = driverNumber
        self.lapNumber = lapNumber
        self.startSessionTime = startSessionTime
        self.endSessionTime = endSessionTime
        self.lapTime = lapTime
        self.sector1 = sector1
        self.sector2 = sector2
        self.sector3 = sector3
        self.isAccurate = isAccurate
    }
}
