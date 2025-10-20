import SwiftUI

struct RootView: View {
    @EnvironmentObject var game: GameState
    @State private var showingSplash = true

    var body: some View {
        NavigationStack {
            ZStack {
                if showingSplash {
                    SplashView {
                        showingSplash = false
                    }
                    .transition(.opacity)
                } else {
                    IntroView()
                        .environmentObject(game)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingSplash)
    }
}
