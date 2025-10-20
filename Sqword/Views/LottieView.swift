import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    var loop: LottieLoopMode = .playOnce
    var speed: CGFloat = 1.0
    var exitAtProgress: CGFloat? = nil      // 0.0 ... 1.0 (e.g., 0.8)
    var exitAfter: TimeInterval? = nil      // seconds (e.g., 1.2)
    var onCompleted: (() -> Void)? = nil

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)
        view.contentMode = .scaleAspectFit
        view.loopMode = .playOnce
        view.animationSpeed = speed
        view.backgroundBehavior = .pauseAndRestore
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        guard !uiView.isAnimationPlaying else { return }

        // If we have a progress cutoff, play to that percentage.
        if let cutoff = exitAtProgress {
            uiView.play(fromProgress: 0, toProgress: cutoff, loopMode: .playOnce) { _ in
                onCompleted?()
            }
        } else {
            // Otherwise, play full—but allow an early time-based exit if requested.
            uiView.play { _ in onCompleted?() }
            if let seconds = exitAfter {
                DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                    if uiView.isAnimationPlaying {
                        uiView.stop()
                        onCompleted?()
                    }
                }
            }
        }
    }
}
