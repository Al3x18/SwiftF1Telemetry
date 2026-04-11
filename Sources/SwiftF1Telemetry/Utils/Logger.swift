import Foundation

enum Logger {
    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        fputs("[SwiftF1Telemetry] \(message())\n", stderr)
        #endif
    }
}
