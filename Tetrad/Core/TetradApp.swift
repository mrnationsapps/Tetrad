import SwiftUI

@main
struct TetradApp: App {
    @StateObject private var game   = GameState()
    @StateObject private var boosts = BoostsService()
    @StateObject private var levels = LevelsService()

    @Environment(\.scenePhase) private var scenePhase

    #if DEBUG
    @StateObject private var debugFlags = DebugFlags()
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                // Core environment objects
                .environmentObject(game)
                .environmentObject(boosts)
                .environmentObject(levels)
                .environmentObject(ToastCenter.shared)

                // Debug-only flags
                #if DEBUG
                .environmentObject(debugFlags)
                #endif

                .onAppear {
                    boosts.resetIfNeeded()
                    levels.loadProgressIfNeeded()
                    
                    // Load totals on launch
                    game.loadAchievementTotals()

                    // 🔗 existing callbacks...
                    boosts.onBoostUsed = { game.noteBoostUsed() }
                    boosts.onBoostPurchased = { count in game.noteBoostPurchased(count: count) }
                    levels.onWorldUnlocked = { _ in game.noteWorldUnlocked() }

                    // Hotfix sync: reflect currently unlocked (non-tutorial) worlds into the counter
                    let nonTutorialUnlocked = levels.unlockedIDs.filter { $0 != "tutorial" }.count
                    if game.worldsUnlockedCount != nonTutorialUnlocked {
                        game.worldsUnlockedCount = nonTutorialUnlocked
                        game.saveAchievementTotals()
                    }
                }

        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                boosts.resetIfNeeded()
                levels.loadProgressIfNeeded()
            }
        }
    }
}
