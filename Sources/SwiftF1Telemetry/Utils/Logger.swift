import Foundation

enum Logger {
    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        let line = "[SwiftF1Telemetry] \(message())\n"
        guard let data = line.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
        #endif
    }
}
