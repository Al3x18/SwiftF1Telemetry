import Foundation

struct TelemetryMerger {
    func merge(carSamples: [CarSample], positionSamples: [PositionSample], lap: Lap) -> [TelemetrySample] {
        let sortedCar = carSamples.sorted { $0.sessionTime < $1.sessionTime }
        return sortedCar.map { car in
            let position = nearestPositionSample(to: car.sessionTime, in: positionSamples)
            return TelemetrySample(
                sessionTime: car.sessionTime,
                lapTime: max(0, car.sessionTime - lap.startSessionTime),
                speed: car.speed,
                rpm: car.rpm,
                throttle: car.throttle,
                brake: car.brake,
                drs: car.drs,
                gear: car.gear,
                x: position?.x,
                y: position?.y,
                z: position?.z,
                status: position?.status,
                distance: nil,
                relativeDistance: nil,
                source: .merged
            )
        }
    }

    private func nearestPositionSample(to sessionTime: TimeInterval, in samples: [PositionSample]) -> PositionSample? {
        samples.min { lhs, rhs in
            abs(lhs.sessionTime - sessionTime) < abs(rhs.sessionTime - sessionTime)
        }
    }
}
