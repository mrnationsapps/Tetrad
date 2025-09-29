//
//  LevelsService.swift
//  Tetrad
//
//  Created by kevin nations on 9/28/25.
//

import Foundation
import SwiftUI

final class LevelsService: ObservableObject {

    // MARK: - Published state
    @Published private(set) var worlds: [World] = WorldsCatalog.all
    @Published private(set) var coins: Int = 0
    @Published var selectedWorldID: String = "tutorial"   // always one selected

    // Persisted sets
    @Published private(set) var unlockedIDs: Set<String> = ["tutorial"]

    // MARK: - Storage keys
    private let kCoins          = "levels.coins"
    private let kUnlockedIDs    = "levels.unlocked.ids"
    private let kSelectedID     = "levels.selected.id"

    init() {
        load()
        // Safety: ensure tutorial is always unlocked and selected by default
        if !unlockedIDs.contains("tutorial") { unlockedIDs.insert("tutorial") }
        if !worlds.contains(where: { $0.id == selectedWorldID }) {
            selectedWorldID = "tutorial"
        }
        reorderWorldsUnlockedFirst()
        save()
    }

    // MARK: - Public helpers

    var selectedWorld: World {
        worlds.first(where: { $0.id == selectedWorldID }) ?? worlds[0]
    }

    func isUnlocked(_ world: World) -> Bool {
        unlockedIDs.contains(world.id) || world.isTutorial
    }

    func select(_ world: World) {
        selectedWorldID = world.id
        saveSelected()
    }

    /// Try to unlock the selected world using coins. Returns true if unlocked.
    @discardableResult
    func unlockSelectedIfPossible() -> Bool {
        let w = selectedWorld
        guard !isUnlocked(w) else { return true }
        guard coins >= w.unlockCost else { return false }
        coins -= w.unlockCost
        unlockedIDs.insert(w.id)
        reorderWorldsUnlockedFirst()
        save()
        return true
    }

    // MARK: - Coins
    func addCoins(_ delta: Int) {
        guard delta != 0 else { return }
        coins = max(0, coins + delta)
        saveCoins()
    }

    // MARK: - Private: ordering + persistence

    private func reorderWorldsUnlockedFirst() {
        worlds.sort { a, b in
            let ua = isUnlocked(a)
            let ub = isUnlocked(b)
            if ua != ub { return ua && !ub }     // unlocked before locked
            if a.isTutorial != b.isTutorial { return a.isTutorial } // tutorial first
            return a.name < b.name
        }
        // Keep selection stable; if selected moved, selectedWorldID still matches
        saveSelected()
    }

    private func load() {
        let ud = UserDefaults.standard

        // coins
        coins = ud.integer(forKey: kCoins)

        // unlocked set
        if let data = ud.data(forKey: kUnlockedIDs),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            unlockedIDs = ids
        } else {
            unlockedIDs = ["tutorial"]
        }

        // selected
        if let sel = ud.string(forKey: kSelectedID) {
            selectedWorldID = sel
        } else {
            selectedWorldID = "tutorial"
        }
    }

    private func save() {
        saveCoins()
        saveUnlocked()
        saveSelected()
    }

    private func saveCoins() {
        UserDefaults.standard.set(coins, forKey: kCoins)
    }

    private func saveUnlocked() {
        if let data = try? JSONEncoder().encode(unlockedIDs) {
            UserDefaults.standard.set(data, forKey: kUnlockedIDs)
        }
    }

    private func saveSelected() {
        UserDefaults.standard.set(selectedWorldID, forKey: kSelectedID)
    }
}

// MARK: - Progression (50 levels per world, de-duplicated names)
extension LevelsService {
    var maxLevelsPerWorld: Int { 50 }

    private var progressKey: String { "levels_progress_v1" }

    // Backing store cached in memory
    private static var _progressStorage: [String: Int]? = nil
    @MainActor private var progress: [String: Int] {
        get { Self._progressStorage ?? [:] }
        set { Self._progressStorage = newValue }
    }

    @MainActor
    func loadProgressIfNeeded() {
        if Self._progressStorage == nil {
            if let d = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int] {
                Self._progressStorage = d
            } else {
                Self._progressStorage = [:]
            }
        }
    }

    @MainActor
    private func saveProgress() {
        UserDefaults.standard.set(progress, forKey: progressKey)
    }

    // 0-based level index (clamped)
    @MainActor
    func levelIndex(for world: World) -> Int {
        let idx = progress[world.id, default: 0]
        return max(0, min(idx, maxLevelsPerWorld - 1))
    }

    @MainActor
    func hasNextLevel(for world: World) -> Bool {
        levelIndex(for: world) < (maxLevelsPerWorld - 1)
    }

    @MainActor
    func advance(from world: World) {
        let idx = progress[world.id, default: 0]
        progress[world.id] = min(idx + 1, maxLevelsPerWorld - 1)
        saveProgress()
    }

    // Deterministic seed
    @MainActor
    func seed(for world: World, levelIndex: Int) -> UInt64 {
        let base = Self.stableHash64(world.id)
        return base &+ UInt64(levelIndex)
    }

    // Stable 64-bit hash
    static func stableHash64(_ s: String) -> UInt64 {
        var h: UInt64 = 5381
        for b in s.utf8 { h = ((h << 5) &+ h) ^ UInt64(b) }
        return h
    }
}

// MARK: - Par & rewards
extension LevelsService {
    @MainActor
    func levelPar(for world: World, levelIndex: Int) -> Int {
        // TODO: derive real order per world/level; placeholder uses 4×4
        let order = 4
        let base = (order == 2 ? 3 : order == 3 ? 10 : 24)
        return base + (levelIndex / 8)
    }

    @MainActor
    func rewardCoins(for moves: Int, par: Int) -> (total: Int, base: Int, bonus: Int) {
        let base = 3
        let bonus = max(0, (par - moves) / 5)
        return (base + bonus, base, bonus)
    }
}



