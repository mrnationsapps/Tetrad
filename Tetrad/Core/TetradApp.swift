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
                    // Daily resets / progress loads
                    boosts.resetIfNeeded()
                    levels.loadProgressIfNeeded()

                    // Callbacks
                    boosts.onBoostUsed = {
                        game.noteBoostUsed()
                    }
                    boosts.onBoostPurchased = { count in
                        game.noteBoostPurchased(count: count)
                    }
                    levels.onWorldUnlocked = { _ in
                        game.noteWorldUnlocked()
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
