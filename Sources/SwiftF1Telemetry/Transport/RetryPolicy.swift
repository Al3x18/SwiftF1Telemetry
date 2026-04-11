import Foundation

struct RetryPolicy: Sendable {
    let maxRetries: Int
    let baseDelayNanoseconds: UInt64

    init(maxRetries: Int, baseDelayNanoseconds: UInt64 = 150_000_000) {
        self.maxRetries = maxRetries
        self.baseDelayNanoseconds = baseDelayNanoseconds
    }

    func delay(forAttempt attempt: Int) -> UInt64 {
        baseDelayNanoseconds * UInt64(max(1, attempt))
    }
}
