//
//  WorldInstructionGate.swift
//  Sqword
//
//  Created by kevin nations on 10/28/25.
//

import SwiftUI
import Lottie

/// Full-screen Lottie that can pause at defined stops and advances on tap.
/// Call `onFinish` when the final segment completes.
struct WorldInstructionGate: View {
    let animationName: String
    /// Progress stops in ascending order (0...1). Example: [0.0, 0.33, 0.66, 1.0]
    /// The player will pause at each intermediate stop and wait for a tap to continue.
    let pauseStops: [CGFloat]
    let onFinish: () -> Void

    @State private var currentStopIndex: Int = 0

    var body: some View {
        ZStack {
            WorldLottiePlayer(
                name: animationName,
                stops: normalizedStops,
                index: $currentStopIndex,
                onFinished: onFinish
            )
            .background {
                Image("Sqword-Splash")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            // Optional “Tap to continue” hint (hidden on last stop)
            if currentStopIndex < max(0, normalizedStops.count - 1) {
                VStack {
                    Spacer()
                    Text("Tap to continue")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 40)
                        .shadow(radius: 6, y: 2)
                }
                .allowsHitTesting(false)
            }

        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Advance to the next segment if there is one
            currentStopIndex += 1
        }
    }

    /// Ensures stops include 0 and 1, sorted and unique
    private var normalizedStops: [CGFloat] {
        var s = Set(pauseStops.map { max(0, min(1, $0)) })
        s.insert(0)
        s.insert(1)
        return s.sorted()
    }
}
