import Foundation

struct DistanceCalculator {
    func applyingDistance(to samples: [TelemetrySample]) -> [TelemetrySample] {
        guard !samples.isEmpty else { return [] }

        var totalDistance = 0.0
        let sorted = samples.sorted { $0.sessionTime < $1.sessionTime }
        let lastIndex = max(0, sorted.count - 1)

        return sorted.enumerated().map { index, sample in
            if index > 0 {
                let previous = sorted[index - 1]
                totalDistance += deltaDistance(from: previous, to: sample)
            }

            let relativeDistance = lastIndex == 0 ? 0.0 : Double(index) / Double(lastIndex)

            return TelemetrySample(
                sessionTime: sample.sessionTime,
                lapTime: sample.lapTime,
                speed: sample.speed,
                rpm: sample.rpm,
                throttle: sample.throttle,
                brake: sample.brake,
                drs: sample.drs,
                gear: sample.gear,
                x: sample.x,
                y: sample.y,
                z: sample.z,
                status: sample.status,
                distance: totalDistance,
                relativeDistance: relativeDistance,
                source: sample.source
            )
        }
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
