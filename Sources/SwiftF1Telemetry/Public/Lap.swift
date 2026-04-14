import Foundation

/// Timing data for a single completed lap.
///
/// Retrieve laps from a ``Session``:
///
/// ```swift
/// let laps = try await session.laps()
///
/// // Filter by driver
/// let maxLaps = laps.filter { $0.driverNumber == "1" && $0.isAccurate }
///
/// // Or get the fastest lap directly
/// let fastest = try await session.fastestLap(driver: "1")
/// ```
public struct Lap: Sendable, Hashable, Codable {
    /// The driver's racing number (e.g. `"1"`, `"16"`).
    public let driverNumber: String
    /// Sequential lap number within the session.
    public let lapNumber: Int
    /// Session clock time when this lap started, in seconds.
    public let startSessionTime: TimeInterval
    /// Session clock time when this lap ended, in seconds.
    public let endSessionTime: TimeInterval
    /// Total lap time in seconds, or `nil` if not available.
    public let lapTime: TimeInterval?
    /// Sector 1 time in seconds, or `nil` if not available.
    public let sector1: TimeInterval?
    /// Sector 2 time in seconds, or `nil` if not available.
    public let sector2: TimeInterval?
    /// Sector 3 time in seconds, or `nil` if not available.
    public let sector3: TimeInterval?
    /// Whether the lap is considered accurate (no major incidents or pit stops).
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
