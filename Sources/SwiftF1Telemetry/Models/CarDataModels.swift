import Foundation

struct CarSample: Sendable, Codable, Hashable {
    let driverNumber: String
    let sessionTime: TimeInterval
    let date: Date?
    let speed: Double?
    let rpm: Double?
    let throttle: Double?
    let brake: Bool?
    let drs: Int?
    let gear: Int?
}

typealias RawCarSample = CarSample
