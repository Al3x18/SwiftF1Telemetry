import Foundation

/// Exposes the current library version string.
///
/// ```swift
/// print(SwiftF1TelemetryVersion.current) // "0.3.2"
/// ```
public enum SwiftF1TelemetryVersion {
    /// The semantic version of the library (e.g. `"0.3.2"`).
    public static let current: String = "0.3.2"
}
