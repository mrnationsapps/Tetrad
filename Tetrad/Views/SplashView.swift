//
//  SplashView.swift
//  Tetrad
//
//  Created by kevin nations on 9/26/25.
//

import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("BoingPopSplash")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 250)
                .scaleEffect(appear ? 1.0 : 0.94)
                .opacity(appear ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { onFinish() }
        }
    }
}
