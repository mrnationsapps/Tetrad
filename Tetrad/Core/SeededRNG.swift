import Foundation
import CryptoKit

/// Simple deterministic RNG seeded from data (or UInt64) and version key.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    // MARK: - Init

    init(seedData: Data) {
        // Use first 8 bytes of SHA256 as initial state
        let hash = SHA256.hash(data: seedData)
        self.state = hash.withUnsafeBytes { raw in
            raw.bindMemory(to: UInt64.self)[0]
        }
    }

    /// Convenience: seed from a UInt64 value
    init(seed: UInt64) {
        var x = seed.littleEndian
        let data = withUnsafeBytes(of: &x) { Data($0) } // 8 bytes
        self.init(seedData: data)
    }

    /// Convenience: seed from any string (e.g., identity keys)
    init(seedString: String) {
        self.init(seedData: Data(seedString.utf8))
    }

    // MARK: - RNG

    mutating func next() -> UInt64 {
        // Xorshift64
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }

    // MARK: - Daily helper

    static func dailySeed(version: String = "TETRAD_v1", date: Date = Date()) -> SeededRNG {
        let utc = ISO8601DateFormatter()
        utc.timeZone = TimeZone(secondsFromGMT: 0)
        utc.formatOptions = [.withFullDate]
        let d = utc.string(from: date) // YYYY-MM-DD in UTC
        let data = Data((version + d).utf8)
        return SeededRNG(seedData: data)
    }
}
