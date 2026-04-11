import Foundation

struct SessionParser {
    private let decoder: JSONDecoder
    private let envelopeParser = RawEnvelopeParser()

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = TimeUtils.parseISO8601(value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
            }
            return date
        }
        self.decoder = decoder
    }

    func parseMetadata(from data: Data) throws -> SessionMetadata {
        if let direct = try? decoder.decode(RawSessionMetadata.self, from: data) {
            return SessionMetadata(
                officialName: direct.officialName,
                circuitName: direct.circuitName,
                scheduledStart: direct.scheduledStart,
                actualStart: direct.actualStart,
                timezoneIdentifier: direct.timezoneIdentifier
            )
        }

        do {
            let normalized = try envelopeParser.normalizedData(from: data)
            let envelope = try decoder.decode(RawSessionMetadataEnvelope.self, from: normalized)
            let infoLines = try envelopeParser.parseJSONStream(envelope.sessionInfoStream)
            guard let infoPayload = infoLines.first?.jsonObject as? [String: Any] else {
                throw F1TelemetryError.parseFailure(dataset: "metadata", description: "SessionInfo stream is empty")
            }

            let meeting = infoPayload["Meeting"] as? [String: Any]
            let circuit = meeting?["Circuit"] as? [String: Any]
            let officialName = (meeting?["OfficialName"] as? String) ?? ((meeting?["Name"] as? String) ?? "Unknown session")
            let circuitName = (circuit?["ShortName"] as? String) ?? ((meeting?["Location"] as? String) ?? "Unknown circuit")
            let scheduledStart = infoPayload["StartDate"] as? String
            let timezoneIdentifier = infoPayload["GmtOffset"] as? String
            let actualStart = parseActualStart(from: envelope.sessionDataJSON)

            return SessionMetadata(
                officialName: officialName,
                circuitName: circuitName,
                scheduledStart: scheduledStart.flatMap(TimeUtils.parseArchiveLocalDate),
                actualStart: actualStart,
                timezoneIdentifier: timezoneIdentifier
            )
        } catch let error as F1TelemetryError {
            throw error
        } catch {
            throw F1TelemetryError.parseFailure(dataset: "metadata", description: String(describing: error))
        }
    }

    private func parseActualStart(from sessionDataJSON: String) -> Date? {
        guard let data = sessionDataJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statusSeries = object["StatusSeries"] as? [[String: Any]] else {
            return nil
        }

        let started = statusSeries.first { entry in
            (entry["SessionStatus"] as? String) == "Started"
        }

        guard let utcString = started?["Utc"] as? String else { return nil }
        return TimeUtils.parseISO8601(utcString)
    }
}
