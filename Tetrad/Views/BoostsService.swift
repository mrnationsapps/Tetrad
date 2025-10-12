//
//  BoostsService.swift
//  Tetrad
//
//  Created by kevin nations on 9/27/25.
//

import Foundation
import Combine

final class BoostsService: ObservableObject {
    // Daily allowance (resets each UTC day)
    private let dailyAllowance = 3

    // UserDefaults keys
    private let keyRemaining     = "boosts.remaining"      // daily bucket
    private let keyPurchased     = "boosts.purchased"      // persistent purchases
    private let keyLastResetUTC  = "boosts.lastResetUTC"   // yyyy-MM-dd (UTC)

    // Live state
    @Published private(set) var remaining: Int   // daily bucket
    @Published private(set) var purchased: Int   // purchased bucket (persists, no daily reset)

    // Callbacks (wired from App): fire on main after use/purchase
    var onBoostUsed: (() -> Void)?
    var onBoostPurchased: ((Int) -> Void)?

    // MARK: - Init
    init() {
        let d = UserDefaults.standard

        // Load purchased (defaults to 0)
        self.purchased = max(0, d.integer(forKey: keyPurchased))

        // Load remaining; default to full allowance on first launch
        if d.object(forKey: keyRemaining) == nil {
            self.remaining = dailyAllowance
            d.set(self.remaining, forKey: keyRemaining)
        } else {
            self.remaining = max(0, d.integer(forKey: keyRemaining))
        }

        // Ensure daily reset semantics are applied at startup
        resetIfNeeded()
    }

    // MARK: - Public API

    /// Total usable boosts (daily + purchased).
    var totalAvailable: Int { remaining + purchased }

    /// Spend one boost if available. Prefers daily, then purchased.
    /// Returns true if a boost was consumed.
    @discardableResult
    func useOne() -> Bool {
        guard totalAvailable > 0 else { return false }

        if remaining > 0 {
            if Thread.isMainThread { remaining -= 1 }
            else { DispatchQueue.main.async { self.remaining -= 1 } }
        } else {
            // daily is 0, draw from purchased
            if Thread.isMainThread { purchased -= 1 }
            else { DispatchQueue.main.async { self.purchased -= 1 } }
        }

        persist()

        // Notify on main
        if Thread.isMainThread { onBoostUsed?() }
        else { DispatchQueue.main.async { self.onBoostUsed?() } }

        return true
    }

    /// Grant free boosts to the **daily** bucket (e.g., rewards).
    func grant(count: Int) {
        guard count > 0 else { return }
        if Thread.isMainThread { remaining += count }
        else { DispatchQueue.main.async { self.remaining += count } }
        persist()
    }

    /// Add boosts to the **purchased** pool (e.g., IAP or shop).
    func purchase(count: Int) {
        guard count > 0 else { return }
        if Thread.isMainThread { purchased += count }
        else { DispatchQueue.main.async { self.purchased += count } }
        persist()

        // Notify on main with how many were added
        if Thread.isMainThread { onBoostPurchased?(count) }
        else { DispatchQueue.main.async { self.onBoostPurchased?(count) } }
    }

    /// Call on app launch and when app becomes active.
    /// If the stored day != today (UTC), resets the daily bucket to the allowance.
    func resetIfNeeded(date: Date = Date()) {
        let todayUTC = Self.utcDayString(date: date)
        let d = UserDefaults.standard
        let last = d.string(forKey: keyLastResetUTC)

        if last != todayUTC {
            if Thread.isMainThread { remaining = dailyAllowance }
            else { DispatchQueue.main.async { self.remaining = self.dailyAllowance } }
            d.set(todayUTC, forKey: keyLastResetUTC)
            persist()
        }
    }

    // MARK: - Persistence

    private func persist() {
        let d = UserDefaults.standard
        d.set(remaining, forKey: keyRemaining)
        d.set(purchased, forKey: keyPurchased)
        // keep lastResetUTC up to date
        d.set(Self.utcDayString(date: Date()), forKey: keyLastResetUTC)
    }

    // MARK: - Utils

    private static func utcDayString(date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)! // UTC
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year!, m = comps.month!, d = comps.day!
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
