import Foundation

struct SessionDatasets: Sendable {
    let laps: [RawLapRecord]
    let carSamples: [CarSample]
    let positionSamples: [PositionSample]
}
