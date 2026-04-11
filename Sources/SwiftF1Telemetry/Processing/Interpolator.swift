import Foundation

struct Interpolator {
    func interpolate(samples: [TelemetrySample]) -> [TelemetrySample] {
        // TODO: Add proper resampling onto a regular lap timeline when upstream data is available.
        samples.sorted { $0.sessionTime < $1.sessionTime }
    }
}
