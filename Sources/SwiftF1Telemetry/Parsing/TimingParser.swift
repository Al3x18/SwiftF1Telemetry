import Foundation

struct TimingParser {
    private let decoder = JSONDecoder()
    private let envelopeParser = RawEnvelopeParser()

    func parseLaps(from data: Data) throws -> [RawLapRecord] {
        if let laps = try? decoder.decode([RawLapRecord].self, from: data) {
            return laps
        }

        do {
            let normalized = try envelopeParser.normalizedData(from: data)
            let envelope = try decoder.decode(RawTimingEnvelope.self, from: normalized)
            let timingLines = try envelopeParser.parseJSONStream(envelope.timingDataStream)
            let stintHints = try parseStintHints(from: envelope.timingAppDataStream)
            return try parseArchiveLaps(from: timingLines, stintHints: stintHints)
        } catch let error as F1TelemetryError {
            throw error
        } catch {
            throw F1TelemetryError.parseFailure(dataset: "timing", description: String(describing: error))
        }
    }

    private func parseArchiveLaps(
        from lines: [RawJSONStreamLine],
        stintHints: [String: [Int: TimeInterval]]
    ) throws -> [RawLapRecord] {
        struct Accumulator {
            var lapNumber: Int
            var endSessionTime: TimeInterval?
            var lapTime: TimeInterval?
            var sector1: TimeInterval?
            var sector2: TimeInterval?
            var sector3: TimeInterval?
        }

        var lapsByDriver: [String: [Int: Accumulator]] = [:]
        var lastFinishedLapByDriver: [String: Int] = [:]

        for line in lines {
            guard let payload = line.jsonObject as? [String: Any],
                  let linesByDriver = payload["Lines"] as? [String: Any] else {
                continue
            }

            for (driver, value) in linesByDriver {
                guard let entry = value as? [String: Any] else { continue }
                let lapTimeValue = parseLapTime(from: entry)
                guard lapTimeValue != nil else { continue }

                let reportedLapCount = parseInt(entry["NumberOfLaps"])
                let lapNumber: Int
                if let reportedLapCount {
                    lapNumber = max(1, reportedLapCount - 1)
                } else {
                    lapNumber = (lastFinishedLapByDriver[driver] ?? 0) + 1
                }

                let sectors = parseSectors(from: entry)
                var accumulator = lapsByDriver[driver, default: [:]][lapNumber] ?? Accumulator(lapNumber: lapNumber)
                accumulator.endSessionTime = line.sessionTime
                accumulator.lapTime = lapTimeValue ?? accumulator.lapTime ?? stintHints[driver]?[lapNumber]
                accumulator.sector1 = sectors.0 ?? accumulator.sector1
                accumulator.sector2 = sectors.1 ?? accumulator.sector2
                accumulator.sector3 = sectors.2 ?? accumulator.sector3
                lapsByDriver[driver, default: [:]][lapNumber] = accumulator
                lastFinishedLapByDriver[driver] = max(lastFinishedLapByDriver[driver] ?? 0, lapNumber)
            }
        }

        return lapsByDriver
            .flatMap { driver, laps in
                laps.values.compactMap { accumulator -> RawLapRecord? in
                    guard let lapTime = accumulator.lapTime,
                          let endSessionTime = accumulator.endSessionTime else {
                        return nil
                    }

                    let startSessionTime = max(0, endSessionTime - lapTime)
                    return RawLapRecord(
                        driverNumber: driver,
                        lapNumber: accumulator.lapNumber,
                        startSessionTime: startSessionTime,
                        endSessionTime: endSessionTime,
                        lapTime: lapTime,
                        sector1: accumulator.sector1,
                        sector2: accumulator.sector2,
                        sector3: accumulator.sector3,
                        isAccurate: true
                    )
                }
            }
            .sorted {
                ($0.driverNumber, $0.lapNumber) < ($1.driverNumber, $1.lapNumber)
            }
    }

    private func parseStintHints(from timingAppDataStream: String?) throws -> [String: [Int: TimeInterval]] {
        guard let timingAppDataStream else { return [:] }
        let lines = try envelopeParser.parseJSONStream(timingAppDataStream)
        var hints: [String: [Int: TimeInterval]] = [:]

        for line in lines {
            guard let payload = line.jsonObject as? [String: Any],
                  let linesByDriver = payload["Lines"] as? [String: Any] else {
                continue
            }

            for (driver, rawDriverEntry) in linesByDriver {
                guard let driverEntry = rawDriverEntry as? [String: Any],
                      let stints = driverEntry["Stints"] as? [String: Any] else {
                    continue
                }

                for (_, rawStint) in stints {
                    guard let stint = rawStint as? [String: Any],
                          let lapNumber = parseInt(stint["LapNumber"]),
                          let lapTimeString = stint["LapTime"] as? String,
                          let lapTime = TimeUtils.parseLapDuration(lapTimeString) else {
                        continue
                    }
                    hints[driver, default: [:]][lapNumber] = lapTime
                }
            }
        }

        return hints
    }

    private func parseLapTime(from entry: [String: Any]) -> TimeInterval? {
        guard let lastLapTime = entry["LastLapTime"] as? [String: Any],
              let value = lastLapTime["Value"] as? String,
              !value.isEmpty else {
            return nil
        }
        return TimeUtils.parseLapDuration(value)
    }

    private func parseSectors(from entry: [String: Any]) -> (TimeInterval?, TimeInterval?, TimeInterval?) {
        guard let sectors = entry["Sectors"] as? [[String: Any]], sectors.count >= 3 else {
            return (nil, nil, nil)
        }

        return (
            TimeUtils.parseLapDuration(sectors[0]["Value"] as? String),
            TimeUtils.parseLapDuration(sectors[1]["Value"] as? String),
            TimeUtils.parseLapDuration(sectors[2]["Value"] as? String)
        )
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
}
