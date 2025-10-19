//
//  BoostsService.swift
//  Tetrad
//
//  Created by kevin nations on 9/27/25.
//

import Foundation
import Combine

@MainActor
final class BoostsService: ObservableObject {
    // 🛑 Purchased-only model: no daily freebies.
    // We keep `remaining` for UI compatibility but it is always 0.
    private let keyPurchased     = "boosts.purchased"     // persistent purchases
    private let keyLastResetUTC  = "boosts.lastResetUTC"  // yyyy-MM-dd (UTC)
    private let legacyKeyRemaining = "boosts.remaining"   // legacy daily bucket (ignore)

    // Live state
    @Published private(set) var purchased: Int
    @Published private(set) var remaining: Int = 0  // legacy, always 0

    // Callbacks (wired from App)
    var onBoostUsed: (() -> Void)?
    var onBoostPurchased: ((Int) -> Void)?

    // MARK: - Init
    init() {
        let d = UserDefaults.standard
        // Load purchased (defaults to 0)
        self.purchased = max(0, d.integer(forKey: keyPurchased))

        // 🔧 Migration: if a legacy daily value exists, zero it out.
        if d.object(forKey: legacyKeyRemaining) != nil {
            d.set(0, forKey: legacyKeyRemaining)
        }

        // Stamp the day so resetIfNeeded remains harmless
        persist()
        resetIfNeeded()

        #if DEBUG
        print("🟣 BoostsService init (purchased-only) purch=\(purchased)")
        #endif
    }

    // MARK: - Public API

    /// Total usable boosts (purchased-only model).
    var totalAvailable: Int { purchased }

    /// Spend one boost if available (consumes **purchased** first).
    @discardableResult
    func useOne() -> Bool {
        guard purchased > 0 else { return false }
        purchased -= 1
        persist()
        onBoostUsed?()
        #if DEBUG
        print("🟣 useOne OK → purch=\(purchased)")
        #endif
        return true
    }

    /// Grant free boosts to the purchased pool (rewards/promo).
    func grant(count: Int) {
        purchase(count: count)
    }

    /// Add boosts to the purchased pool (IAP or wallet buys).
    func purchase(count: Int) {
        guard count > 0 else { return }
        purchased += count
        persist()
        onBoostPurchased?(count)
        #if DEBUG
        print("🟣 purchase(+\(count)) → purch=\(purchased)")
        #endif
    }

    /// Keep the stored UTC day up to date; no daily refill.
    func resetIfNeeded(date: Date = Date()) {
        let todayUTC = Self.utcDayString(date: date)
        let d = UserDefaults.standard
        let last = d.string(forKey: keyLastResetUTC)
        if last != todayUTC {
            d.set(todayUTC, forKey: keyLastResetUTC)
            persist()
        }
    }

    // MARK: - Persistence

    private func persist() {
        let d = UserDefaults.standard
        d.set(purchased, forKey: keyPurchased)
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
