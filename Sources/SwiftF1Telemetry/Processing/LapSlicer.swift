import Foundation

struct LapSlicer {
    func sliceCarSamples(_ samples: [CarSample], for lap: Lap) -> [CarSample] {
        samples.filter { sample in
            sample.driverNumber == lap.driverNumber &&
            sample.sessionTime >= lap.startSessionTime &&
            sample.sessionTime <= lap.endSessionTime
        }
    }

    func slicePositionSamples(_ samples: [PositionSample], for lap: Lap) -> [PositionSample] {
        samples.filter { sample in
            sample.driverNumber == lap.driverNumber &&
            sample.sessionTime >= lap.startSessionTime &&
            sample.sessionTime <= lap.endSessionTime
        }
    }
}
