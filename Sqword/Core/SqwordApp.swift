import SwiftUI
import StoreKit


@main
struct SqwordApp: App {
    @StateObject private var game   = GameState()
    @StateObject private var boosts = BoostsService()
    @StateObject private var levels = LevelsService()
    @StateObject private var store = IAPManager()


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
                .environmentObject(store)
                .task {
                    await store.loadProducts()
                }
                .onAppear {
                    // Credit coins by productID for delayed updates:
                    store.startTransactionListener { productID in
                        if let sku = CoinProduct(rawValue: productID) {
                            Task { @MainActor in levels.addCoins(sku.coinAmount) }
                        }
                    }
                }

                // Debug-only flags
                #if DEBUG
                .environmentObject(debugFlags)
                #endif

                // Wire callbacks & do one-time startup work once the objects are installed
                .task { @MainActor in
                    // Initial sync
                    boosts.resetIfNeeded()
                    levels.loadProgressIfNeeded()
                    game.loadAchievementTotals()

                    // Wire cross-object callbacks exactly once
                    boosts.onBoostUsed = { [weak game] in
                        Task { @MainActor in game?.noteBoostUsed() }
                    }
                    boosts.onBoostPurchased = { [weak game] count in
                        Task { @MainActor in game?.noteBoostPurchased(count: count) }
                    }
                    levels.onWorldUnlocked = { [weak game] _ in
                        Task { @MainActor in game?.noteWorldUnlocked() }
                    }

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
