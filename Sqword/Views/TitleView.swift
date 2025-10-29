import SwiftUI

struct TitleView: View {
    var onFinish: () -> Void
    @State private var appear = false
    @EnvironmentObject private var music: MusicCenter


    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("Sqword-Splash")
                .resizable()
                .scaledToFill()
        }
        .ignoresSafeArea()
        .overlay {
            Image("Sqword-title")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 560)
                .padding(.horizontal, 80)
                .offset(y: -100)
        }
        .overlay(alignment: .bottom) {
            Button(action: onFinish) {
                Text("Continue")
                    .font(.title3).bold()
                    .foregroundStyle(.primary)
            }
            .buttonStyle(SoftRaisedPillStyle(height: 52))
            .padding(.bottom, 80)
            .frame(width: 200)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        
        .onAppear { music.enterMenu() }

    }
}
