//
//  Persistence.swift
//  Tetrad
//
//  Created by kevin nations on 9/25/25.

import Foundation

// MARK: - Lightweight persistence models

struct PuzzleIdentity: Codable, Equatable {
    /// UTC day key like "2025-09-25"
    let dayUTC: String
    /// 16 letters as a single string (lowercase a–z)
    let bag: String
}

struct TilePlacement: Codable, Equatable {
    let row: Int
    let col: Int
    let letter: Character

    private enum CodingKeys: String, CodingKey { case row, col, letter }

    init(row: Int, col: Int, letter: Character) {
        self.row = row
        self.col = col
        self.letter = letter
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        row = try c.decode(Int.self, forKey: .row)
        col = try c.decode(Int.self, forKey: .col)
        let s = try c.decode(String.self, forKey: .letter)
        guard s.count == 1, let ch = s.first else {
            throw DecodingError.dataCorruptedError(forKey: .letter, in: c,
                debugDescription: "Expected single-character string")
        }
        letter = ch
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(row, forKey: .row)
        try c.encode(col, forKey: .col)
        try c.encode(String(letter), forKey: .letter)
    }
}


struct RunState: Codable, Equatable {
    var moves: Int
    var solvedToday: Bool
    var placements: [TilePlacement]
    var streak: Int
    var lastPlayedDayUTC: String
}

// MARK: - Keys & helpers

enum PersistKeys {
    static let identity = "tetrad.identity.v1"
    static let runState = "tetrad.runState.v1"
}

enum Persistence {
    static func save<T: Codable>(_ value: T, key: String) {
        let enc = JSONEncoder()
        if let data = try? enc.encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    static func load<T: Codable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    static func clearForNewDay() {
        UserDefaults.standard.removeObject(forKey: PersistKeys.identity)
        UserDefaults.standard.removeObject(forKey: PersistKeys.runState)
    }
    static func saveIdentity(_ v: PuzzleIdentity) { save(v, key: PersistKeys.identity) }
    static func loadIdentity() -> PuzzleIdentity? { load(key: PersistKeys.identity) }

    static func saveRunState(_ v: RunState) { save(v, key: PersistKeys.runState) }
    static func loadRunState() -> RunState? { load(key: PersistKeys.runState) }
}

func currentUTCDateKey(_ date: Date = Date()) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let c = cal.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
}

func isConsecutiveUTC(_ prev: String, _ today: String) -> Bool {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd"
    guard let dPrev = f.date(from: prev), let dToday = f.date(from: today) else { return false }
    if let next = f.calendar!.date(byAdding: .day, value: 1, to: dPrev) {
        return f.calendar!.isDate(next, inSameDayAs: dToday)
    }
    return false
}
