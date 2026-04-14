import Foundation

/// Parsing and formatting helpers for F1 time strings.
///
/// ```swift
/// // Parse a lap time string into seconds
/// let seconds = TimeUtils.parseLapDuration("1:21.584")  // 81.584
///
/// // Format seconds back into a readable string
/// let display = TimeUtils.format(seconds: 81.584)        // "1:21.584"
/// ```
public enum TimeUtils {
    /// Parses a clock-style duration (`"HH:mm:ss.fff"`) into seconds.
    ///
    /// ```swift
    /// TimeUtils.parseClockDuration("0:02:15.300") // 135.3
    /// ```
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

    /// Parses a lap-time string into seconds.
    ///
    /// Accepts multiple formats: `"81.584"`, `"1:21.584"`, or `"0:01:21.584"`.
    ///
    /// ```swift
    /// TimeUtils.parseLapDuration("1:21.584") // 81.584
    /// ```
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

    /// Parses an ISO 8601 date string, with or without fractional seconds.
    ///
    /// ```swift
    /// let date = TimeUtils.parseISO8601("2024-09-01T14:00:00Z")
    /// ```
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

    /// Parses a local date string in the archive format (`"yyyy-MM-dd'T'HH:mm:ss"`).
    ///
    /// ```swift
    /// let date = TimeUtils.parseArchiveLocalDate("2024-09-01T14:00:00")
    /// ```
    public static func parseArchiveLocalDate(_ value: String) -> Date? {
        let archiveLocalDate = DateFormatter()
        archiveLocalDate.locale = Locale(identifier: "en_US_POSIX")
        archiveLocalDate.timeZone = TimeZone(secondsFromGMT: 0)
        archiveLocalDate.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return archiveLocalDate.date(from: value)
    }

    /// Formats a time interval as `"m:ss.SSS"`, or `"n/a"` when `nil`.
    ///
    /// ```swift
    /// TimeUtils.format(seconds: 81.584) // "1:21.584"
    /// TimeUtils.format(seconds: nil)    // "n/a"
    /// ```
    public static func format(seconds: TimeInterval?) -> String {
        guard let seconds else { return "n/a" }
        let minutes = Int(seconds) / 60
        let remainder = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%06.3f", minutes, remainder)
    }

}
