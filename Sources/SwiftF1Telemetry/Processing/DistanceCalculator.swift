import Foundation

struct DistanceCalculator {
    func applyingDistance(to samples: [TelemetrySample]) -> [TelemetrySample] {
        guard !samples.isEmpty else { return [] }

        var result = samples.sorted { $0.sessionTime < $1.sessionTime }

        result[0].distance = 0
        for i in 1..<result.count {
            result[i].distance = result[i - 1].distance! + deltaDistance(from: result[i - 1], to: result[i])
        }

        let totalDistance = result.last!.distance!
        for i in result.indices {
            result[i].relativeDistance = totalDistance > 0 ? result[i].distance! / totalDistance : 0
        }

        return result
    }

    private func deltaDistance(from previous: TelemetrySample, to current: TelemetrySample) -> Double {
        if let px = previous.x, let py = previous.y, let cx = current.x, let cy = current.y {
            // F1 position coordinates are reported in 1/10 meter.
            let dx = (cx - px) / 10.0
            let dy = (cy - py) / 10.0
            return (dx * dx + dy * dy).squareRoot()
        }

        let deltaTime = max(0, current.sessionTime - previous.sessionTime)
        let averageSpeedKmh = ((previous.speed ?? 0) + (current.speed ?? previous.speed ?? 0)) / 2
        return (averageSpeedKmh / 3.6) * deltaTime
    }
}
