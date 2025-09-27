//
//  BoostsService.swift
//  Tetrad
//
//  Created by kevin nations on 9/27/25.
//

import Foundation
import Combine

final class BoostsService: ObservableObject {
    @Published private(set) var remaining: Int
    private let dailyAllowance = 3
    private let keyRemaining = "boosts.remaining"
    private let keyLastResetUTC = "boosts.lastResetUTC" // yyyy-MM-dd (UTC)

    init() {
        let d = UserDefaults.standard
        self.remaining = max(0, d.integer(forKey: keyRemaining))
        resetIfNeeded() // initialize properly on first run / new day
        if UserDefaults.standard.object(forKey: keyRemaining) == nil {
            // First install → give full allowance
            remaining = dailyAllowance
            persist()
        }
    }

    /// Call on app launch & when app becomes active.
    func resetIfNeeded(date: Date = Date()) {
        let utcYYYYMMDD = Self.utcDayString(date: date)
        let d = UserDefaults.standard
        let last = d.string(forKey: keyLastResetUTC)
        if last != utcYYYYMMDD {
            remaining = dailyAllowance
            d.set(utcYYYYMMDD, forKey: keyLastResetUTC)
            persist()
        }
    }

    func useOne() -> Bool {
        guard remaining > 0 else { return false }
        remaining -= 1
        persist()
        return true
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(remaining, forKey: keyRemaining)
        let today = Self.utcDayString(date: Date())
        d.set(today, forKey: keyLastResetUTC)
    }

    private static func utcDayString(date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)! // UTC
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year!, m = comps.month!, d = comps.day!
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
