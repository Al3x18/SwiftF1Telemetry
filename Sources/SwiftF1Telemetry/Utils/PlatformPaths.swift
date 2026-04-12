import Foundation

enum PlatformPaths {
    static func defaultCacheDirectory(named directoryName: String) -> URL {
        let environment = ProcessInfo.processInfo.environment

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        if let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            return cacheDirectory.appendingPathComponent(directoryName, isDirectory: true)
        }
        #endif

        if let xdgCacheHome = environment["XDG_CACHE_HOME"], xdgCacheHome.isEmpty == false {
            return URL(fileURLWithPath: xdgCacheHome, isDirectory: true)
                .appendingPathComponent(directoryName, isDirectory: true)
        }

        if let home = environment["HOME"], home.isEmpty == false {
            return URL(fileURLWithPath: home, isDirectory: true)
                .appendingPathComponent(".cache", isDirectory: true)
                .appendingPathComponent(directoryName, isDirectory: true)
        }

        return FileManager.default.temporaryDirectory.appendingPathComponent(directoryName, isDirectory: true)
    }
}
