import Foundation

struct TelemetryComparisonCalculator {
    func compare(reference: TelemetryTrace, compared: TelemetryTrace) throws -> TelemetryComparison {
        let referencePoints = normalizedPoints(from: reference)
        let comparedPoints = normalizedPoints(from: compared)

        guard referencePoints.count >= 2 else {
            throw F1TelemetryError.internalInvariantViolation(
                description: "Reference telemetry requires at least two distance-aligned samples for comparison"
            )
        }

        guard comparedPoints.count >= 2 else {
            throw F1TelemetryError.internalInvariantViolation(
                description: "Compared telemetry requires at least two distance-aligned samples for comparison"
            )
        }

        let grid = sharedGrid(reference: referencePoints, compared: comparedPoints)
        let samples: [TelemetryComparisonSample] = grid.compactMap { progress in
            guard let referenceSample = interpolatedSample(at: progress, in: referencePoints),
                  let comparedSample = interpolatedSample(at: progress, in: comparedPoints) else {
                return nil
            }

            let distance = mergedDistance(reference: referenceSample.distance, compared: comparedSample.distance)
            let delta = comparedSample.lapTime - referenceSample.lapTime

            return TelemetryComparisonSample(
                distance: distance,
                relativeDistance: progress,
                referenceLapTime: referenceSample.lapTime,
                comparedLapTime: comparedSample.lapTime,
                delta: delta,
                referenceSpeed: referenceSample.speed,
                referenceRPM: referenceSample.rpm,
                referenceThrottle: referenceSample.throttle,
                referenceBrake: referenceSample.brake,
                referenceDRS: referenceSample.drs,
                referenceGear: referenceSample.gear,
                comparedSpeed: comparedSample.speed,
                comparedRPM: comparedSample.rpm,
                comparedThrottle: comparedSample.throttle,
                comparedBrake: comparedSample.brake,
                comparedDRS: comparedSample.drs,
                comparedGear: comparedSample.gear
            )
        }

        return TelemetryComparison(reference: reference, compared: compared, samples: samples)
    }

    private func normalizedPoints(from trace: TelemetryTrace) -> [TelemetrySample] {
        trace.samples
            .filter { $0.relativeDistance != nil }
            .sorted { ($0.relativeDistance ?? 0) < ($1.relativeDistance ?? 0) }
    }

    private func sharedGrid(reference: [TelemetrySample], compared: [TelemetrySample]) -> [Double] {
        let combined = reference.compactMap(\.relativeDistance) + compared.compactMap(\.relativeDistance)
        let sorted = combined.sorted()

        var deduplicated: [Double] = []
        deduplicated.reserveCapacity(sorted.count)

        for value in sorted {
            guard let last = deduplicated.last else {
                deduplicated.append(value)
                continue
            }

            if abs(last - value) > 0.000_001 {
                deduplicated.append(value)
            }
        }

        return deduplicated
    }

    private func interpolatedSample(at progress: Double, in samples: [TelemetrySample]) -> TelemetrySample? {
        guard let first = samples.first, let last = samples.last else { return nil }
        guard let firstProgress = first.relativeDistance, let lastProgress = last.relativeDistance else { return nil }

        if progress <= firstProgress {
            return first
        }

        if progress >= lastProgress {
            return last
        }

        for index in 1..<samples.count {
            let previous = samples[index - 1]
            let current = samples[index]

            guard let lower = previous.relativeDistance, let upper = current.relativeDistance else { continue }
            guard progress >= lower, progress <= upper else { continue }

            if abs(upper - lower) < 0.000_001 {
                return current
            }

            let fraction = (progress - lower) / (upper - lower)

            return TelemetrySample(
                sessionTime: interpolate(previous.sessionTime, current.sessionTime, fraction),
                lapTime: interpolate(previous.lapTime, current.lapTime, fraction),
                speed: interpolate(previous.speed, current.speed, fraction),
                rpm: interpolate(previous.rpm, current.rpm, fraction),
                throttle: interpolate(previous.throttle, current.throttle, fraction),
                brake: fraction < 0.5 ? previous.brake : current.brake,
                drs: interpolateStep(previous.drs, current.drs, fraction),
                gear: interpolateStep(previous.gear, current.gear, fraction),
                x: interpolate(previous.x, current.x, fraction),
                y: interpolate(previous.y, current.y, fraction),
                z: interpolate(previous.z, current.z, fraction),
                status: fraction < 0.5 ? previous.status : current.status,
                distance: interpolate(previous.distance, current.distance, fraction),
                relativeDistance: progress,
                source: .interpolated
            )
        }

        return samples.last
    }

    private func mergedDistance(reference: Double?, compared: Double?) -> Double? {
        switch (reference, compared) {
        case let (.some(reference), .some(compared)):
            return (reference + compared) / 2
        case let (.some(reference), .none):
            return reference
        case let (.none, .some(compared)):
            return compared
        case (.none, .none):
            return nil
        }
    }

    private func interpolate(_ lhs: Double, _ rhs: Double, _ fraction: Double) -> Double {
        lhs + ((rhs - lhs) * fraction)
    }

    private func interpolate(_ lhs: Double?, _ rhs: Double?, _ fraction: Double) -> Double? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return interpolate(lhs, rhs, fraction)
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private func interpolateStep<T>(_ lhs: T?, _ rhs: T?, _ fraction: Double) -> T? {
        fraction < 0.5 ? lhs ?? rhs : rhs ?? lhs
    }
}
