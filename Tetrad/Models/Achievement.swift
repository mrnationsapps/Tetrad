//
//  Achievement.swift
//  Tetrad
//
//  Created by kevin nations on 9/26/25.
//

import Foundation

struct Achievement: Identifiable {
    let id = UUID()
    let key: String
    let title: String
    let subtitle: String
    let symbol: String   // SF Symbol

    // Unlock logic driven by current GameState
    let condition: (GameState) -> Bool

    func isUnlocked(using game: GameState) -> Bool {
        condition(game)
    }
}

extension Achievement {
    static let all: [Achievement] = [
        .init(
            key: "first_solve",
            title: "First Solve",
            subtitle: "Complete your first daily puzzle.",
            symbol: "star.fill",
            condition: { $0.solved }
        ),
        .init(
            key: "streak_3",
            title: "On a Roll",
            subtitle: "3-day solve streak.",
            symbol: "flame.fill",
            condition: { $0.streak >= 3 }
        ),
        .init(
            key: "streak_7",
            title: "Hot Streak",
            subtitle: "7-day solve streak.",
            symbol: "flame",
            condition: { $0.streak >= 7 }
        ),
        .init(
            key: "efficient_10",
            title: "Efficient Thinker",
            subtitle: "Solve in 10 moves or fewer.",
            symbol: "bolt.fill",
            condition: { $0.solved && $0.moveCount <= 10 }
        ),
        .init(
            key: "perfect_fill",
            title: "Perfect Fill",
            subtitle: "Finish with no re-placements.",
            symbol: "circlebadge",
            condition: { $0.solved && $0.moveCount == 0 }
        ),
        .init(
            key: "daily_return",
            title: "Come Back Tomorrow",
            subtitle: "Solve two days in a row.",
            symbol: "clock.fill",
            condition: { $0.streak >= 2 }
        )
    ]
}
