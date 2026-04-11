import CryptoKit
import Foundation

struct CacheKey: Sendable, Hashable {
    let year: Int
    let meeting: String
    let session: String
    let dataset: String
    let version: String

    init(session: SessionRef, dataset: String, version: String = "v2") {
        self.year = session.year
        self.meeting = session.meeting
        self.session = session.sessionType.rawValue
        self.dataset = dataset
        self.version = version
    }

    var filename: String {
        let raw = "\(version)|\(year)|\(meeting.lowercased())|\(session)|\(dataset)"
        let digest = Insecure.SHA1.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".json"
    }
}
