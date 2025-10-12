import Foundation
import CryptoKit

/// Simple deterministic RNG seeded from date string (UTC) and version key.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seedData: Data) {
        // Use first 8 bytes of SHA256 as initial state
        let hash = SHA256.hash(data: seedData)
        self.state = hash.withUnsafeBytes { raw in
            raw.bindMemory(to: UInt64.self)[0]
        }
    }

    mutating func next() -> UInt64 {
        // Xorshift64*
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }

    static func dailySeed(version: String = "TETRAD_v1", date: Date = Date()) -> SeededRNG {
        let utc = ISO8601DateFormatter()
        utc.timeZone = TimeZone(secondsFromGMT: 0)
        utc.formatOptions = [.withFullDate]
        let d = utc.string(from: date) // YYYY-MM-DD in UTC
        let data = Data((version + d).utf8)
        return SeededRNG(seedData: data)
    }
}
