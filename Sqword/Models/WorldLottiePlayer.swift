//
//  WorldLottiePlayer.swift
//  Sqword
//
//  Created by kevin nations on 10/28/25.
//
import SwiftUI
import Lottie

/// A thin bridge around Lottie’s AnimationView that plays segment-by-segment.
/// - Plays from stops[i] → stops[i+1], then pauses.
/// - When `index` reaches the last stop, it completes and calls `onFinished`.
struct WorldLottiePlayer: UIViewRepresentable {
    let name: String
    let stops: [CGFloat]       // normalized progress (0...1)
    @Binding var index: Int
    let onFinished: () -> Void

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let view = LottieAnimationView(name: name)
        view.contentMode = .scaleAspectFit
        view.loopMode = .playOnce
        view.backgroundBehavior = .pauseAndRestore

        container.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        context.coordinator.player = view
        // Start at first stop (usually 0), and immediately play the first segment.
        DispatchQueue.main.async {
            context.coordinator.playSegment(fromIndex: 0, stops: stops, onFinished: onFinished)
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // If index changed (user tapped), resume next segment.
        context.coordinator.playSegment(fromIndex: index, stops: stops, onFinished: onFinished)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var player: LottieAnimationView?
        private var lastPlayedIndex: Int = -1

        func playSegment(fromIndex newIndex: Int, stops: [CGFloat], onFinished: @escaping () -> Void) {
            guard let player else { return }
            guard !stops.isEmpty else { onFinished(); return }

            // Prevent re-triggering the same segment
            guard newIndex != lastPlayedIndex else { return }
            lastPlayedIndex = newIndex

            // If we’re at or beyond the last stop, finish.
            if newIndex >= stops.count - 1 {
                onFinished()
                return
            }

            let start = stops[newIndex]
            let end   = stops[newIndex + 1]

            // Play segment [start, end], then pause (unless end == 1 which completes)
            player.currentProgress = start
            player.play(fromProgress: start, toProgress: end, loopMode: .playOnce) { _ in
                // If not final, just pause here until the next tap bumps index.
                if newIndex + 1 < stops.count - 1 {
                    player.pause()
                } else {
                    onFinished()
                }
            }
        }
    }
}

