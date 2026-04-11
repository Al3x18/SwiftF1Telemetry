import Foundation

struct CarDataParser {
    private let decoder = JSONDecoder()
    private let envelopeParser = RawEnvelopeParser()

    func parseSamples(from data: Data) throws -> [CarSample] {
        if let samples = try? decoder.decode([CarSample].self, from: data) {
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
            throw F1TelemetryError.parseFailure(dataset: "car", description: String(describing: error))
        }
    }

    private func parseArchiveSamples(
        lines: [RawJSONStreamLine],
        sessionStartDate _: Date
    ) -> [CarSample] {
        struct PendingSample {
            let driverNumber: String
            let rawTime: TimeInterval
            let date: Date
            let speed: Double?
            let rpm: Double?
            let throttle: Double?
            let brake: Bool?
            let drs: Int?
            let gear: Int?
        }

        var pending: [PendingSample] = []

        for line in lines {
            guard let payload = line.jsonObject as? [String: Any],
                  let entries = payload["Entries"] as? [[String: Any]] else {
                continue
            }

            for entry in entries {
                guard let utcString = entry["Utc"] as? String,
                      let utcDate = TimeUtils.parseISO8601(utcString),
                      let cars = entry["Cars"] as? [String: Any] else {
                    continue
                }

                for (driver, rawCar) in cars {
                    guard let car = rawCar as? [String: Any],
                          let channels = car["Channels"] as? [String: Any] else {
                        continue
                    }

                    pending.append(
                        PendingSample(
                            driverNumber: driver,
                            rawTime: line.sessionTime,
                            date: utcDate,
                            speed: parseDouble(channels["2"]),
                            rpm: parseDouble(channels["0"]),
                            throttle: parseDouble(channels["4"]),
                            brake: parseBrake(channels["5"]),
                            drs: parseInt(channels["45"]),
                            gear: parseInt(channels["3"])
                        )
                    )
                }
            }
        }

        let t0Date = pending.map { $0.date.timeIntervalSince1970 - $0.rawTime }.max() ?? 0

        return pending.map { sample in
            CarSample(
                driverNumber: sample.driverNumber,
                sessionTime: sample.date.timeIntervalSince1970 - t0Date,
                date: sample.date,
                speed: sample.speed,
                rpm: sample.rpm,
                throttle: sample.throttle,
                brake: sample.brake,
                drs: sample.drs,
                gear: sample.gear
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

    private func parseInt(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let string as String:
            return Int(string)
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }

    private func parseBrake(_ value: Any?) -> Bool? {
        guard let int = parseInt(value) else { return nil }
        return int != 0
    }
}
