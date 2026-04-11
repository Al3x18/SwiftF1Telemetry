import Foundation

public enum SessionType: String, Sendable, Codable {
    case practice1 = "FP1"
    case practice2 = "FP2"
    case practice3 = "FP3"
    case sprintShootout = "SQ"
    case sprint = "S"
    case qualifying = "Q"
    case race = "R"
}

public struct SessionRef: Sendable, Hashable {
    public let year: Int
    public let meeting: String
    public let sessionType: SessionType
    public let backendIdentifier: String
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

public struct SessionMetadata: Sendable, Hashable {
    public let officialName: String
    public let circuitName: String
    public let scheduledStart: Date?
    public let actualStart: Date?
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
    let key: Int
    let type: String
    let number: Int?
    let name: String
    let startDate: String
    let endDate: String
    let gmtOffset: String
    let path: String

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
