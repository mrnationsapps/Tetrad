import SwiftUI

@main
struct TetradApp: App {
    @StateObject private var game = GameState()
    @StateObject private var boosts = BoostsService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .environmentObject(boosts)
                .onAppear { boosts.resetIfNeeded() }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { boosts.resetIfNeeded() }
        }
    }
}
