//
//  Achievement.swift
//  Tetrad
//
//  Created by kevin nations on 9/26/25.
//

import SwiftUI

struct Achievement: Identifiable {
    let id = UUID()
    let key: String
    let title: String
    let subtitle: String
    let rewardCoins: Int
    let condition: (GameState) -> Bool

    // Unlocked?
    func isUnlocked(using game: GameState) -> Bool {
        condition(game)
    }

    // Claimed bookkeeping (simple UserDefaults per-achievement key)
    private var claimedKey: String { "ach.claimed.\(key)" }

    func isClaimed() -> Bool {
        UserDefaults.standard.bool(forKey: claimedKey)
    }

    /// Convenience for UI: unlocked AND not yet claimed
    func isClaimable(using game: GameState) -> Bool {
        isUnlocked(using: game) && !isClaimed()
    }

    /// Mark this achievement’s reward as claimed.
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
            rewardCoins: 3,
            condition: { _ in
                // Matches the flag set in TutorialWorldView.markTutorialCompleted()
                UserDefaults.standard.bool(forKey: "ach.tutorial.completed")
            }
        ),

        .init(
            key: "first_solve",
            title: "First Solve",
            subtitle: "Complete your first daily puzzle.",
            rewardCoins: 3,
            condition: { $0.solved }
        ),

        .init(
            key: "streak_3",
            title: "On a Roll",
            subtitle: "3-day solve streak.",
            rewardCoins: 3,
            condition: { $0.streak >= 3 }
        ),
        .init(
            key: "streak_7",
            title: "Hot Streak",
            subtitle: "7-day solve streak.",
            rewardCoins: 3,
            condition: { $0.streak >= 7 }
        ),
        .init(
            key: "efficient_10",
            title: "Efficient Thinker",
            subtitle: "Solve in 10 moves or fewer.",
            rewardCoins: 3,
            condition: { $0.solved && $0.moveCount <= 10 }
        ),
        .init(
            key: "perfect_fill",
            title: "Perfect Fill",
            subtitle: "Finish with no re-placements.",
            rewardCoins: 3,
            condition: { $0.solved && $0.moveCount == 0 }
        ),
        .init(
            key: "daily_return",
            title: "Come Back Tomorrow",
            subtitle: "Solve two days in a row.",
            rewardCoins: 3,
            condition: { $0.streak >= 2 }
        )
        // Add more achievements here, each with a rewardCoins value.
    ]
}
