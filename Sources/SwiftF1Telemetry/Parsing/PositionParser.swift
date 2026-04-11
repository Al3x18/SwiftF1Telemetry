import Foundation

struct PositionParser {
    private let decoder = JSONDecoder()
    private let envelopeParser = RawEnvelopeParser()

    func parseSamples(from data: Data) throws -> [PositionSample] {
        if let samples = try? decoder.decode([PositionSample].self, from: data) {
            return samples
        }

        do {
            let normalized = try envelopeParser.normalizedData(from: data)
            let envelope = try decoder.decode(RawTelemetryEnvelope.self, from: normalized)
            let lines = try envelopeParser.parseCompressedJSONStream(envelope.stream)
            return parseArchiveSamples(lines: lines, sessionStartDate: envelope.sessionStartDate)
        } catch let error as F1TelemetryError {
            throw error
        } catch {
            throw F1TelemetryError.parseFailure(dataset: "position", description: String(describing: error))
        }
    }

    private func parseArchiveSamples(
        lines: [RawJSONStreamLine],
        sessionStartDate _: Date
    ) -> [PositionSample] {
        struct PendingSample {
            let driverNumber: String
            let rawTime: TimeInterval
            let date: Date
            let x: Double?
            let y: Double?
            let z: Double?
            let status: String?
        }

        var pending: [PendingSample] = []

        for line in lines {
            guard let payload = line.jsonObject as? [String: Any],
                  let positions = payload["Position"] as? [[String: Any]] else {
                continue
            }

            for entry in positions {
                guard let utcString = entry["Timestamp"] as? String,
                      let utcDate = TimeUtils.parseISO8601(utcString),
                      let drivers = entry["Entries"] as? [String: Any] else {
                    continue
                }

                for (driver, rawPosition) in drivers {
                    guard let position = rawPosition as? [String: Any] else { continue }
                    pending.append(
                        PendingSample(
                            driverNumber: driver,
                            rawTime: line.sessionTime,
                            date: utcDate,
                            x: parseDouble(position["X"]),
                            y: parseDouble(position["Y"]),
                            z: parseDouble(position["Z"]),
                            status: position["Status"] as? String
                        )
                    )
                }
            }
        }

        let t0Date = pending.map { $0.date.timeIntervalSince1970 - $0.rawTime }.max() ?? 0

        return pending.map { sample in
            PositionSample(
                driverNumber: sample.driverNumber,
                sessionTime: sample.date.timeIntervalSince1970 - t0Date,
                date: sample.date,
                x: sample.x,
                y: sample.y,
                z: sample.z,
                status: sample.status
            )
        }
        .sorted { $0.sessionTime < $1.sessionTime }
    }

    private func parseDouble(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let string as String:
            return Double(string)
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }
}
