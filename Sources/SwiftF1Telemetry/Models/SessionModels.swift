import Foundation

/// The type of session within a race weekend.
///
/// Pass a session type when resolving a session from ``F1Client``:
///
/// ```swift
/// let session = try await client.session(
///     year: 2024,
///     meeting: "Monza",
///     session: .qualifying
/// )
/// ```
public enum SessionType: String, Sendable, Codable {
    case practice1 = "FP1"
    case practice2 = "FP2"
    case practice3 = "FP3"
    case sprintShootout = "SQ"
    case sprint = "S"
    case qualifying = "Q"
    case race = "R"
}

/// Stable reference that uniquely identifies a resolved session in the archive.
///
/// You normally don't create this yourself — it is provided by ``Session/ref``
/// after resolving a session:
///
/// ```swift
/// let session = try await client.session(year: 2024, meeting: "Monza", session: .race)
/// print(session.ref.archivePath)
/// ```
public struct SessionRef: Sendable, Hashable, Codable {
    /// Season year (e.g. `2024`).
    public let year: Int
    /// Meeting name used for resolution (e.g. `"Monza"`).
    public let meeting: String
    /// The type of session within the meeting.
    public let sessionType: SessionType
    /// Upstream identifier for this session.
    public let backendIdentifier: String
    /// Archive path used to fetch session data.
    public let archivePath: String

    public init(
        year: Int,
        meeting: String,
        sessionType: SessionType,
        backendIdentifier: String,
        archivePath: String
    ) {
        self.year = year
        self.meeting = meeting
        self.sessionType = sessionType
        self.backendIdentifier = backendIdentifier
        self.archivePath = archivePath
    }
}

/// Human-readable metadata for a resolved session.
///
/// Accessible via ``Session/metadata``:
///
/// ```swift
/// let session = try await client.session(year: 2024, meeting: "Monza", session: .race)
/// print(session.metadata.officialName)   // e.g. "FORMULA 1 GRAN PREMIO D'ITALIA 2024"
/// print(session.metadata.circuitName)    // e.g. "Monza"
/// ```
public struct SessionMetadata: Sendable, Hashable, Codable {
    /// The official name of the event (e.g. `"FORMULA 1 GRAN PREMIO D'ITALIA 2024"`).
    public let officialName: String
    /// The circuit short name (e.g. `"Monza"`).
    public let circuitName: String
    /// Scheduled session start time, or `nil` if unavailable.
    public let scheduledStart: Date?
    /// Actual session start time, or `nil` if unavailable.
    public let actualStart: Date?
    /// IANA timezone identifier for the venue, or `nil` if unavailable.
    public let timezoneIdentifier: String?

    public init(
        officialName: String,
        circuitName: String,
        scheduledStart: Date?,
        actualStart: Date?,
        timezoneIdentifier: String?
    ) {
        self.officialName = officialName
        self.circuitName = circuitName
        self.scheduledStart = scheduledStart
        self.actualStart = actualStart
        self.timezoneIdentifier = timezoneIdentifier
    }
}

struct RawSessionMetadata: Sendable, Codable {
    let officialName: String
    let circuitName: String
    let scheduledStart: Date?
    let actualStart: Date?
    let timezoneIdentifier: String?
}

struct RawSessionMetadataEnvelope: Sendable, Codable {
    let sessionInfoStream: String
    let sessionDataJSON: String
}

struct RawTimingEnvelope: Sendable, Codable {
    let timingDataStream: String
    let timingAppDataStream: String?
    let heartbeatStream: String?
    let sessionStartDate: Date?
}

struct RawTelemetryEnvelope: Sendable, Codable {
    let sessionStartDate: Date
    let stream: String
}

struct RawSeasonIndex: Sendable, Codable {
    let year: Int
    let meetings: [RawMeeting]

    enum CodingKeys: String, CodingKey {
        case year = "Year"
        case meetings = "Meetings"
    }
}

struct RawMeeting: Sendable, Codable {
    let name: String
    let officialName: String
    let location: String
    let circuit: RawCircuit
    let sessions: [RawArchiveSession]

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case officialName = "OfficialName"
        case location = "Location"
        case circuit = "Circuit"
        case sessions = "Sessions"
    }
}

struct RawCircuit: Sendable, Codable {
    let shortName: String

    enum CodingKeys: String, CodingKey {
        case shortName = "ShortName"
    }
}

struct RawArchiveSession: Sendable, Codable {
    let key: Int?
    let type: String
    let number: Int?
    let name: String?
    let startDate: String?
    let endDate: String?
    let gmtOffset: String?
    let path: String?

    enum CodingKeys: String, CodingKey {
        case key = "Key"
        case type = "Type"
        case number = "Number"
        case name = "Name"
        case startDate = "StartDate"
        case endDate = "EndDate"
        case gmtOffset = "GmtOffset"
        case path = "Path"
    }
}
