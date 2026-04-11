import Foundation

public enum TimeUtils {
    public static func parseClockDuration(_ value: String?) -> TimeInterval? {
        guard let value else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else {
            return nil
        }
        return (hours * 3600) + (minutes * 60) + seconds
    }

    public static func parseLapDuration(_ value: String?) -> TimeInterval? {
        guard let value, !value.isEmpty else { return nil }
        let parts = value.split(separator: ":")
        switch parts.count {
        case 1:
            return Double(parts[0])
        case 2:
            guard let minutes = Double(parts[0]), let seconds = Double(parts[1]) else { return nil }
            return (minutes * 60) + seconds
        case 3:
            return parseClockDuration(value)
        default:
            return nil
        }
    }

    public static func parseISO8601(_ value: String) -> Date? {
        let iso8601WithFractional = ISO8601DateFormatter()
        iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601WithFractional.date(from: value) {
            return date
        }
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]
        return iso8601.date(from: value)
    }

    public static func parseArchiveLocalDate(_ value: String) -> Date? {
        let archiveLocalDate = DateFormatter()
        archiveLocalDate.locale = Locale(identifier: "en_US_POSIX")
        archiveLocalDate.timeZone = TimeZone(secondsFromGMT: 0)
        archiveLocalDate.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return archiveLocalDate.date(from: value)
    }

    public static func format(seconds: TimeInterval?) -> String {
        guard let seconds else { return "n/a" }
        let minutes = Int(seconds) / 60
        let remainder = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%06.3f", minutes, remainder)
    }

}
