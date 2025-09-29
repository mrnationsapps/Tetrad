import SwiftUI

@main
struct TetradApp: App {
    @StateObject private var game   = GameState()
    @StateObject private var boosts = BoostsService()
    @StateObject private var levels = LevelsService()   // ⬅️ add this

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .environmentObject(boosts)
                .environmentObject(levels)              // ⬅️ inject into environment
                .onAppear {
                    boosts.resetIfNeeded()
                    levels.loadProgressIfNeeded()       // ⬅️ load per-world progress once
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                boosts.resetIfNeeded()
                // Optional safety: refresh progress if needed after app returns
                levels.loadProgressIfNeeded()
            }
        }
    }
}
