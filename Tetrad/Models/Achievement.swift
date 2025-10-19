//
//  Achievement.swift
//  Tetrad
//
//  Created by kevin nations on 9/26/25.
//

import SwiftUI

struct Achievement: Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let subtitle: String
    let rewardCoins: Int

    // Make the closure main-actor isolated
    let condition: @MainActor (GameState) -> Bool

    // Unlocked?
    @MainActor
    func isUnlocked(using game: GameState) -> Bool {
        condition(game)
    }

    private var claimedKey: String { "ach.claimed.\(key)" }

    func isClaimed() -> Bool {
        UserDefaults.standard.bool(forKey: claimedKey)
    }

    /// unlocked AND not yet claimed
    @MainActor
    func isClaimable(using game: GameState) -> Bool {
        isUnlocked(using: game) && !isClaimed()
    }

    func markClaimed() {
        UserDefaults.standard.set(true, forKey: claimedKey)
    }
}


// MARK: - Catalog
extension Achievement {
    static var all: [Achievement] = [
        .init(
            key: "tutorial",
            title: "Tutorial Complete",
            subtitle: "Learn how to play.",
            rewardCoins: 5,
            condition: { _ in
                UserDefaults.standard.bool(forKey: "ach.tutorial.completed")
            }
        ),

        .init(
            key: "unlock_world",
            title: "First World",
            subtitle: "Unlock your first World.",
            rewardCoins: 15,
            condition: { $0.worldsUnlockedCount >= 1 }
        ),

        .init(
            key: "five_levels",
            title: "Just Getting Started",
            subtitle: "Solve 5 Levels.",
            rewardCoins: 15,
            condition: { $0.totalLevelsSolved >= 5 }
        ),

        .init(
            key: "five_boosts",
            title: "A Little Help",
            subtitle: "Buy 5 Boosts.",
            rewardCoins: 15,
            condition: { $0.boostsPurchasedTotal >= 5 }
        ),

        .init(
            key: "first_daily",
            title: "First Daily Solve",
            subtitle: "Complete your first daily puzzle.",
            rewardCoins: 10,
            condition: { $0.totalDailiesSolved >= 1 }
        ),

        .init(
            key: "streak_3_daily",
            title: "On a Roll",
            subtitle: "3-day Daily streak.",
            rewardCoins: 15,
            condition: { $0.streak >= 3 }
        ),

        .init(
            key: "streak_7_daily",
            title: "Hot Streak",
            subtitle: "7-day Daily streak.",
            rewardCoins: 15,
            condition: { $0.streak >= 7 }
        ),

        .init(
            key: "efficient_10",
            title: "Efficient Thinker",
            subtitle: "Solve in 10 moves or fewer.",
            rewardCoins: 25,
            // Mode-agnostic, persists once earned
            condition: { _ in
                UserDefaults.standard.bool(forKey: "ach.unlocked.efficient_10")
            }
        ),

        .init(
            key: "perfect_fill",
            title: "Perfect Fill",
            subtitle: "Finish with no boosts.",
            rewardCoins: 15,
            // Mode-agnostic, persists once earned
            condition: { _ in
                UserDefaults.standard.bool(forKey: "ach.unlocked.perfect_fill")
            }
        ),

        .init(
            key: "daily_return",
            title: "Come Back Tomorrow",
            subtitle: "Solve two dailies in a row.",
            rewardCoins: 10,
            condition: { $0.streak >= 2 }
        )
    ]
}


// MARK: - Queries / helpers for toasts & badges
extension Achievement {
    @MainActor
    static func unclaimed(using game: GameState) -> [Achievement] {
        all.filter { $0.isUnlocked(using: game) && !$0.isClaimed() }
    }

    @discardableResult
    @MainActor
    static func claimAll(using game: GameState, levels: LevelsService) -> Int {
        let pending = unclaimed(using: game)
        var total = 0
        for a in pending where !a.isClaimed() {
            a.markClaimed()
            total += a.rewardCoins
        }
        if total > 0 { levels.addCoins(total) }
        return total
    }
}




