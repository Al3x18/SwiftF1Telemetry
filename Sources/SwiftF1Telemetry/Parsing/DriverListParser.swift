import Foundation

struct RawDriverEntry: Sendable {
    let racingNumber: String
    let firstName: String?
    let lastName: String?
    let fullName: String?
    let abbreviation: String?
    let broadcastName: String?
    let teamName: String?
    let teamColour: String?
    let countryCode: String?
}

struct DriverListParser {
    private let envelopeParser = RawEnvelopeParser()

    func parse(from data: Data) throws -> [RawDriverEntry] {
        guard let string = String(data: data, encoding: .utf8), !string.isEmpty else {
            throw F1TelemetryError.parseFailure(dataset: "driverList", description: "Empty payload")
        }

        let lines = try envelopeParser.parseJSONStream(string)
        var drivers: [String: [String: Any]] = [:]

        for line in lines {
            guard let patch = line.jsonObject as? [String: Any] else { continue }
            for (number, value) in patch {
                guard let info = value as? [String: Any] else { continue }
                var existing = drivers[number, default: [:]]
                for (key, val) in info {
                    existing[key] = val
                }
                drivers[number] = existing
            }
        }

        return drivers.compactMap { number, info in
            RawDriverEntry(
                racingNumber: (info["RacingNumber"] as? String) ?? number,
                firstName: info["FirstName"] as? String,
                lastName: info["LastName"] as? String,
                fullName: info["FullName"] as? String,
                abbreviation: info["Tla"] as? String,
                broadcastName: info["BroadcastName"] as? String,
                teamName: info["TeamName"] as? String,
                teamColour: info["TeamColour"] as? String,
                countryCode: info["CountryCode"] as? String
            )
        }
        .sorted { $0.racingNumber.localizedStandardCompare($1.racingNumber) == .orderedAscending }
    }
}
