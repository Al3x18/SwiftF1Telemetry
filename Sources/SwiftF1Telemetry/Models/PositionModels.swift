import Foundation

struct PositionSample: Sendable, Codable, Hashable {
    let driverNumber: String
    let sessionTime: TimeInterval
    let date: Date?
    let x: Double?
    let y: Double?
    let z: Double?
    let status: String?
}

typealias RawPositionSample = PositionSample
