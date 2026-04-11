import Foundation

struct DeltaCalculator {
    func delta(reference: TelemetryTrace, comparedTo candidate: TelemetryTrace) -> [ChartPoint<Double>] {
        let referencePairs: [Double: Double] = Dictionary(uniqueKeysWithValues: reference.samples.compactMap { sample in
            guard let relativeDistance = sample.relativeDistance else { return nil }
            return (relativeDistance, sample.lapTime)
        })

        return candidate.samples.compactMap { sample in
            guard let relativeDistance = sample.relativeDistance,
                  let referenceLapTime = referencePairs[relativeDistance] else {
                return nil
            }
            return ChartPoint(x: relativeDistance, y: sample.lapTime - referenceLapTime)
        }
    }
}
