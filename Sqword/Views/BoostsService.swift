//
//  BoostsService.swift
//  Sqword
//
//  Created by kevin nations on 9/27/25.
//

import Foundation
import Combine

@MainActor
final class BoostsService: ObservableObject {
    enum BoostKind { case reveal, clarity }

    private let keyPurchased       = "boosts.purchased"
    private let keyLastResetUTC    = "boosts.lastResetUTC"
    private let legacyKeyRemaining = "boosts.remaining"
    private let kReveal            = "boosts.reveal.count"
    private let kClarity           = "boosts.clarity.count"

    @Published private(set) var purchased: Int         // legacy bucket (kept for migration/toast)
    @Published private(set) var remaining: Int = 0     // legacy, always 0
    @Published private(set) var revealRemaining: Int
    @Published private(set) var clarityRemaining: Int

    var onBoostUsed: (() -> Void)?
    var onBoostPurchased: ((Int) -> Void)?

    init() {
        let d = UserDefaults.standard

        // 1) Load legacy purchased first (local), sanitize
        let initialPurchased = max(0, d.integer(forKey: keyPurchased))

        // 2) Load new per-kind counts (locals)
        let storedReveal  = d.object(forKey: kReveal)  as? Int
        let storedClarity = d.object(forKey: kClarity) as? Int

        // 3) Compute starting inventories (locals)
        //    If this is the first run on the new scheme, migrate legacy `purchased` into Reveal.
        let startReveal  = max(0, storedReveal  ?? initialPurchased)
        let startClarity = max(0, storedClarity ?? 0)

        // 4) Now assign all stored properties
        self.purchased        = initialPurchased
        self.revealRemaining  = startReveal
        self.clarityRemaining = startClarity

        // 5) Clean up truly old daily key
        if d.object(forKey: legacyKeyRemaining) != nil {
            d.set(0, forKey: legacyKeyRemaining)
        }

        // 6) Persist day stamp + the new per-kind counts
        persist()

        #if DEBUG
//        print("🟣 BoostsService init → purch=\(purchased) reveal=\(revealRemaining) clarity=\(clarityRemaining)")
        #endif
    }

    // MARK: - Public API

    func count(for kind: BoostKind) -> Int {
        switch kind {
        case .reveal:  return revealRemaining
        case .clarity: return clarityRemaining
        }
    }

    @discardableResult
    func useOne(kind: BoostKind) -> Bool {
        switch kind {
        case .reveal:
            guard revealRemaining > 0 else { return false }
            revealRemaining -= 1
        case .clarity:
            guard clarityRemaining > 0 else { return false }
            clarityRemaining -= 1
        }
        persist()
        onBoostUsed?()
        return true
    }

    func grant(count: Int, kind: BoostKind) {
        guard count > 0 else { return }
        switch kind {
        case .reveal:  revealRemaining  += count
        case .clarity: clarityRemaining += count
        }
        persist()
        onBoostPurchased?(count)
    }

    // If you still need the legacy helpers elsewhere:
    var totalAvailable: Int { revealRemaining + clarityRemaining }

    // MARK: - Persistence

    private func persist() {
        let d = UserDefaults.standard
        d.set(purchased, forKey: keyPurchased) // keep writing for old code paths
        d.set(revealRemaining,  forKey: kReveal)
        d.set(clarityRemaining, forKey: kClarity)
        d.set(Self.utcDayString(date: Date()), forKey: keyLastResetUTC)
    }

    func resetIfNeeded(date: Date = Date()) {
        let d = UserDefaults.standard
        let today = Self.utcDayString(date: date)
        if d.string(forKey: keyLastResetUTC) != today {
            d.set(today, forKey: keyLastResetUTC)
            persist()
        }
    }

    /// Purchase (legacy). Treat as purchasing **Reveal**.
    func purchase(count: Int) {
        grant(count: count, kind: .reveal)
    }
    
    private static func utcDayString(date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = cal.dateComponents([.year,.month,.day], from: date)
        return String(format:"%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}



