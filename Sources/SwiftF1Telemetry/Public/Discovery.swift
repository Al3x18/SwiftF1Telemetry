import Foundation

/// A discoverable F1 event for a specific season.
public struct EventDescriptor: Sendable, Hashable, Codable {
    /// Season year.
    public let year: Int
    /// Event name used for matching and session resolution.
    public let name: String
    /// Official event name from the archive index.
    public let officialName: String
    /// Event location from the archive index.
    public let location: String
    /// Circuit short name from the archive index.
    public let circuitName: String

    public init(year: Int, name: String, officialName: String, location: String, circuitName: String) {
        self.year = year
        self.name = name
        self.officialName = officialName
        self.location = location
        self.circuitName = circuitName
    }
}

/// A discoverable session for a specific event.
public struct SessionDescriptor: Sendable, Hashable, Codable {
    /// Season year.
    public let year: Int
    /// Event name that owns the session.
    public let eventName: String
    /// Session type currently supported by the library.
    public let sessionType: SessionType
    /// Human-readable archive session name.
    public let name: String
    /// Scheduled session start when available.
    public let startDate: Date?
    /// Scheduled session end when available.
    public let endDate: Date?

    public init(
        year: Int,
        eventName: String,
        sessionType: SessionType,
        name: String,
        startDate: Date?,
        endDate: Date?
    ) {
        self.year = year
        self.eventName = eventName
        self.sessionType = sessionType
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// A driver that has lap-backed telemetry available for a selected session.
public struct DriverDescriptor: Sendable, Hashable, Codable {
    /// Driver racing number (e.g. `"16"`).
    public let driverNumber: String
    /// First name when available (e.g. `"Charles"`).
    public let firstName: String?
    /// Last name when available (e.g. `"Leclerc"`).
    public let lastName: String?
    /// Full name as provided by the archive (e.g. `"Charles LECLERC"`).
    public let fullName: String?
    /// Three-letter abbreviation (e.g. `"LEC"`).
    public let abbreviation: String?
    /// Broadcast-style name (e.g. `"C LECLERC"`).
    public let broadcastName: String?
    /// Team name when available (e.g. `"Ferrari"`).
    public let teamName: String?
    /// Team colour hex string when available (e.g. `"E80020"`).
    public let teamColour: String?
    /// ISO country code when available (e.g. `"MON"`).
    public let countryCode: String?

    public init(
        driverNumber: String,
        firstName: String? = nil,
        lastName: String? = nil,
        fullName: String? = nil,
        abbreviation: String? = nil,
        broadcastName: String? = nil,
        teamName: String? = nil,
        teamColour: String? = nil,
        countryCode: String? = nil
    ) {
        self.driverNumber = driverNumber
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.abbreviation = abbreviation
        self.broadcastName = broadcastName
        self.teamName = teamName
        self.teamColour = teamColour
        self.countryCode = countryCode
    }
}
