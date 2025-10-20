//
//  LevelsService.swift
//  Sqword
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

    // Tutorial coin gate (persisted)
    @Published var tutorialCompleted: Bool = false

    // 🔔 Callback: fired once when a world transitions locked → unlocked
    // Wire in App: levels.onWorldUnlocked = { _ in game.noteWorldUnlocked() }
    var onWorldUnlocked: ((World) -> Void)?

    // MARK: - Storage keys
    private let kCoins               = "levels.coins"
    private let kUnlockedIDs         = "levels.unlocked.ids"
    private let kSelectedID          = "levels.selected.id"
    private let kTutorialCompleted   = "levels.tutorial.completed" // NEW

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

    var hasUnlockedNonTutorial: Bool {
        unlockedIDs.contains { id in
            if let w = worlds.first(where: { $0.id == id }) {
                return !w.isTutorial
            }
            return false
        }
    }

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

    // Returns the amount actually awarded (0 if blocked)
    @discardableResult
    func awardCoinsIfAllowed(_ amount: Int, in world: World?, markTutorialCompletedIfFinal: Bool = false) -> Int {
        guard amount > 0 else { return 0 }

        // Tutorial gating
        if let w = world, w.isTutorial {
            if tutorialCompleted { return 0 }        // replays: no coins
            addCoins(amount)
            if markTutorialCompletedIfFinal {
                markTutorialCompleted()
            }
            return amount
        }

        // Non-tutorial: always award
        addCoins(amount)
        return amount
    }

    // Convenience for tutorial flows when you don't have a World instance handy
    @discardableResult
    func awardCoinsIfAllowedInTutorial(_ amount: Int, markCompletedIfFinal: Bool = false) -> Int {
        guard amount > 0 else { return 0 }
        if tutorialCompleted { return 0 }
        addCoins(amount)
        if markCompletedIfFinal {
            markTutorialCompleted()
        }
        return amount
    }


    /// Try to unlock the selected world using coins. Returns true if unlocked.
    @discardableResult
    func unlockSelectedIfPossible() -> Bool {
        let w = selectedWorld
        // Already unlocked? nothing to do
        guard !isUnlocked(w) else { return true }
        // Enough coins?
        guard coins >= w.unlockCost else { return false }

        // Spend & unlock
        coins -= w.unlockCost
        let wasLocked = !unlockedIDs.contains(w.id)
        unlockedIDs.insert(w.id)
        reorderWorldsUnlockedFirst()
        save()

        // 🔔 Fire once (non-tutorial only) on the transition
        if wasLocked && !w.isTutorial {
            if Thread.isMainThread { onWorldUnlocked?(w) }
            else { DispatchQueue.main.async { self.onWorldUnlocked?(w) } }
        }
        return true
    }

    // MARK: - Coins
    func addCoins(_ delta: Int) {
        guard delta != 0 else { return }
        coins = max(0, coins + delta)
        saveCoins()
    }

    // MARK: - Tutorial coin gating

    /// True if tutorial coins are still allowed (i.e., first completion not yet recorded).
    var tutorialCoinsEnabled: Bool { !tutorialCompleted }

    /// Call this when the player finishes the **final tutorial level** for the first time.
    func markTutorialCompleted() {
        guard !tutorialCompleted else { return }
        tutorialCompleted = true
        saveTutorialCompleted()
    }

    /// Returns false if this is a tutorial world **and** the tutorial has already been completed.
    func shouldAwardCoins(in world: World?) -> Bool {
        guard let w = world else { return true }
        if w.isTutorial && tutorialCompleted { return false }
        return true
    }

    /// Helper to zero out a computed payout tuple for tutorial replays.
    func gatedPayout(total: Int, bonus: Int, for world: World?) -> (total: Int, bonus: Int) {
        guard let w = world, w.isTutorial, tutorialCompleted else {
            return (total, bonus)
        }
        return (0, 0)
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

        // tutorial completed
        tutorialCompleted = ud.bool(forKey: kTutorialCompleted)
    }

    private func save() {
        saveCoins()
        saveUnlocked()
        saveSelected()
        saveTutorialCompleted()
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

    private func saveTutorialCompleted() {
        UserDefaults.standard.set(tutorialCompleted, forKey: kTutorialCompleted)
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

    // Deterministic seed — unique per world + level index
    @MainActor
    func seed(for world: World, levelIndex: Int) -> UInt64 {
        // Stable across installs/builds; different for each (world,id,level)
        let s = "Sqword.level.v1|\(world.id)|L\(levelIndex)"
        var rng = SeededRNG(seedString: s)
        return rng.next()
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
        let base = 5
        let bonus = max(0, (par - moves) / 10)
        return (base + bonus, base, bonus)
    }
}

// MARK: - Centralized “buy boost with coins” helper — no GameState dependency
extension LevelsService {
    @discardableResult
    @MainActor
    func buyBoost(
        cost: Int,
        count: Int = 1,
        boosts: BoostsService,
        haptics: Bool = true
    ) -> Bool {
        guard coins >= cost else { return false }
        addCoins(-cost)
        boosts.purchase(count: count)   // ✅ persistent purchased pool
        #if os(iOS)
        if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        #endif
        return true
    }
}


