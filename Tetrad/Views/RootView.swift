import SwiftUI

struct RootView: View {
    @EnvironmentObject var game: GameState

    // simple gate to skip onboarding next launches
    @AppStorage("bp_didOnboard") private var didOnboard: Bool = false

    @State private var showingSplash = true

    var body: some View {
        ZStack {
            if showingSplash {
                SplashView {
                    showingSplash = false
                }
                .transition(.opacity)
            } else if !didOnboard {
                NewGameView(
                    profile: PlayerProfile.load(),
                    onGo: { profile in
                        // Persist via your model (already saved in PlayerProfile.save()).
                        didOnboard = true
                    },
                    onBack: {
                        // If back is pressed, show the splash again
                        showingSplash = true
                    }
                )
                .transition(.opacity)
            } else {
                IntroView()
                    .environmentObject(game)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingSplash)
        .animation(.easeInOut(duration: 0.25), value: didOnboard)
    }
}
