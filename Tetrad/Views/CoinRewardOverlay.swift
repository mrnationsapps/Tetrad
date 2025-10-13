//
//  CoinRewardOverlay.swift
//  Tetrad
//
//  Created by kevin nations on 10/12/25.
//

import SwiftUI

struct CoinRewardOverlay: View {
    @Binding var isPresented: Bool
    let amount: Int
    var animationName: String = "Dollar_Coins_Chest"
    var showBackdrop: Bool = true
    var coinTextDelay: TimeInterval = 1.00    // ⬅️ NEW: delay before showing “+N Coins”
    var onFinished: (() -> Void)? = nil

    // Container animation
    @State private var scale: CGFloat = 0.85
    @State private var opacity: CGFloat = 0.0

    // Centered “+N” animation
    @State private var coinScale: CGFloat = 0.01
    @State private var coinOpacity: Double = 0

    private var amountText: String { "+\(amount)" }

    var body: some View {
        ZStack {
            if showBackdrop {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            ZStack {
                // Lottie animation
                LottieView(
                    name: animationName,
                    loop: .playOnce,
                    speed: 1.0,
                    exitAtProgress: 0.7,
                    onCompleted: {
                        // 1) quick overshoot pop
                        withAnimation(.easeOut(duration: 0.10)) {
                            scale = 1.30
                        }
                        // 2) then shrink-to-zero (in place) + fade
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                                scale = 0.01
                                opacity = 0.0
                            }
                            // 3) remove after the shrink completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                                isPresented = false
                                onFinished?()
                            }
                        }
                    }
                )
                .frame(width: 260, height: 260)

                // Centered dynamic coin text
                VStack(spacing: 6) {
                    Text(amountText)
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(radius: 8, y: 2)
                        .scaleEffect(coinScale)
                        .opacity(coinOpacity)

                    Text("")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 6, y: 2)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(Text("+\(amount) coins"))
            }
            .frame(width: 260, height: 260)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                // Entry pop-in for container
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    scale = 1.0
                    opacity = 1.0
                }
                // “+N” text 0 → 100% with a tiny overshoot, timed by coinTextDelay
                withAnimation(.easeOut(duration: 0.10).delay(coinTextDelay)) {
                    coinOpacity = 1.0
                    coinScale = 1.18
                }
                withAnimation(.spring(response: 0.30, dampingFraction: 0.85).delay(coinTextDelay + 0.10)) {
                    coinScale = 1.0
                }
            }
        }
        .accessibilityAddTraits(.isModal)
    }
}
