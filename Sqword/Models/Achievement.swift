//
//  Achievement.swift
//  Sqword
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
            key: "unlock_second_world",
            title: "Steppin' Out",
            subtitle: "Unlock two Worlds.",
            rewardCoins: 20,
            condition: { $0.worldsUnlockedCount >= 2 }
        ),

        .init(
            key: "unlock_third_world",
            title: "Explorer",
            subtitle: "Unlock three Worlds.",
            rewardCoins: 20,
            condition: { $0.worldsUnlockedCount >= 3 }
        ),
        
        .init(
            key: "unlock_forth_world",
            title: "World Traveler",
            subtitle: "Unlock four Worlds.",
            rewardCoins: 25,
            condition: { $0.worldsUnlockedCount >= 4 }
        ),
    
        .init(
            key: "unlock_fifth_world",
            title: "Magellan",
            subtitle: "Unlock five Worlds.",
            rewardCoins: 40,
            condition: { $0.worldsUnlockedCount >= 5 }
        ),
    
        .init(
            key: "unlock_sixth_world",
            title: "Globe Trotter",
            subtitle: "Unlock six Worlds.",
            rewardCoins: 45,
            condition: { $0.worldsUnlockedCount >= 6 }
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
            subtitle: "Buy 3 Boosts.",
            rewardCoins: 10,
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
            rewardCoins: 45,
            condition: { $0.streak >= 7 }
        ),
        
        .init(
            key: "daily_coins",
            title: "Come Back Tomorrow",
            subtitle: "Congrats, you're hooked.",
            rewardCoins: 15,
            condition: { game in
                // Only unlockable if:
                // 1. They've solved at least one daily (so they understand the game)
                // 2. They haven't claimed today yet
                guard game.totalDailiesSolved >= 1 else { return false }
                
                let lastClaimedKey = "ach.daily_coins.lastClaimed"
                let lastClaimed = UserDefaults.standard.string(forKey: lastClaimedKey)
                
                // Get today's date in UTC
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.formatOptions = [.withFullDate]
                let today = formatter.string(from: Date())
                
                // Can claim if never claimed before, or last claimed on a different day
                return lastClaimed != today
            }
        ),
        
        .init(
            key: "efficient_10",
            title: "Efficient Thinker",
            subtitle: "Solve in 10 moves or fewer.",
            rewardCoins: 30,
            // Mode-agnostic, persists once earned
            condition: { _ in
                UserDefaults.standard.bool(forKey: "ach.unlocked.efficient_10")
            }
        ),

        .init(
            key: "perfect_fill",
            title: "Perfect Fill",
            subtitle: "Finish with no boosts.",
            rewardCoins: 20,
            // Mode-agnostic, persists once earned
            condition: { _ in
                UserDefaults.standard.bool(forKey: "ach.unlocked.perfect_fill")
            }
        ),
        
            .init(
                key: "complete_food_world",
                title: "Culinary Expert",
                subtitle: "Complete all Food World levels.",
                rewardCoins: 50,
                condition: { _ in
                    UserDefaults.standard.bool(forKey: "world.food.completed")
                }
            ),

            .init(
                key: "ten_world_words",
                title: "Word Hunter",
                subtitle: "Find 10 World Words.",
                rewardCoins: 40,
                condition: { _ in
                    UserDefaults.standard.integer(forKey: "stats.worldWordsFound") >= 10
                }
            ),
        
            .init(
                key: "ten_boosts",
                title: "Power User",
                subtitle: "Buy 10 Boosts.",
                rewardCoins: 20,
                condition: { $0.boostsPurchasedTotal >= 10 }
            ),

            .init(
                key: "fifty_boosts",
                title: "Boost Enthusiast",
                subtitle: "Buy 50 Boosts.",
                rewardCoins: 40,
                condition: { $0.boostsPurchasedTotal >= 50 }
            ),

            .init(
                key: "coin_collector",
                title: "Coin Collector",
                subtitle: "Accumulate 150 coins.",
                rewardCoins: 20,
                condition: { _ in
                    // You'd need to track total coins earned in GameState
                    UserDefaults.standard.integer(forKey: "stats.totalCoinsEarned") >= 150
                }
            ),
        
            .init(
                key: "streak_14_daily",
                title: "Two Week Warrior",
                subtitle: "14-day Daily streak.",
                rewardCoins: 40,
                condition: { $0.streak >= 14 }
            ),

            .init(
                key: "streak_30_daily",
                title: "Monthly Master",
                subtitle: "30-day Daily streak.",
                rewardCoins: 50,
                condition: { $0.streak >= 30 }
            ),

            .init(
                key: "streak_100_daily",
                title: "Dedication Incarnate",
                subtitle: "100-day Daily streak.",
                rewardCoins: 60,
                condition: { $0.streak >= 100 }
            ),
        
            .init(
                key: "ten_levels",
                title: "Warming Up",
                subtitle: "Solve 10 Levels.",
                rewardCoins: 30,
                condition: { $0.totalLevelsSolved >= 10 }
            ),

            .init(
                key: "twenty_five_levels",
                title: "Committed Player",
                subtitle: "Solve 25 Levels.",
                rewardCoins: 40,
                condition: { $0.totalLevelsSolved >= 25 }
            ),

            .init(
                key: "fifty_levels",
                title: "Half Century",
                subtitle: "Solve 50 Levels.",
                rewardCoins: 50,
                condition: { $0.totalLevelsSolved >= 50 }
            ),

            .init(
                key: "hundred_levels",
                title: "Century Club",
                subtitle: "Solve 100 Levels.",
                rewardCoins: 60,
                condition: { $0.totalLevelsSolved >= 100 }
            ),
        
            .init(
                key: "efficient_5",
                title: "Speed Demon",
                subtitle: "Solve in 5 moves or fewer.",
                rewardCoins: 40,
                condition: { _ in
                    UserDefaults.standard.bool(forKey: "ach.unlocked.efficient_5")
                }
            ),

            .init(
                key: "efficient_15",
                title: "Getting the Hang of It",
                subtitle: "Solve in 15 moves or fewer.",
                rewardCoins: 20,
                condition: { _ in
                    UserDefaults.standard.bool(forKey: "ach.unlocked.efficient_15")
                }
            ),

            .init(
                key: "world_word_speedrun",
                title: "Quick Study",
                subtitle: "Find a World Word in under 5 moves.",
                rewardCoins: 20,
                condition: { _ in
                    UserDefaults.standard.bool(forKey: "ach.unlocked.world_word_speedrun")
                }
            ),

        .init(
            key: "daily_return",
            title: "Daily Again? Heck yes.",
            subtitle: "Solve two dailies in a row.",
            rewardCoins: 15,
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
            
            // Special handling for daily_coins - track claim date
            if a.key == "daily_coins" {
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.formatOptions = [.withFullDate]
                let today = formatter.string(from: Date())
                UserDefaults.standard.set(today, forKey: "ach.daily_coins.lastClaimed")
            }
            
            total += a.rewardCoins
        }
        if total > 0 { levels.addCoins(total) }
        return total
    }
}




