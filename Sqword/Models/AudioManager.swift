import AVFoundation

final class AudioManager {
    static let shared = AudioManager()
    private init() {}

    // MARK: - Player & State
    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?

    /// Clamp-able target music volume for “full” volume (0…1). Defaults to 0.45 to match your previous call.
    var baseVolume: Float = 0.45

    /// Hard guard to ignore resumes while in gameplay (MusicCenter can flip this).
    var allowResume: Bool = true

    var isPlaying: Bool { player?.isPlaying ?? false }
    var isLoaded:  Bool { player != nil }

    // MARK: - Core playback

    /// Play a looping background track from the app bundle.
    /// - Note: Sets the player volume to **0** and starts playback immediately so you can fade in smoothly.
    func playBGM(named name: String, ext: String = "mp3", volume: Float = 0.45, loop: Bool = true) {
        // If already playing *something*, keep going (callers will decide to stop/fade/etc.)
        if let p = player, p.isPlaying { return }

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
//            print("⚠️ AudioManager: Missing resource \(name).\(ext)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = loop ? -1 : 0
            baseVolume = max(0, min(1, volume))
            p.volume = 0.0                       // start silent; fadeInAndPlay() will ramp to baseVolume
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
//            print("⚠️ AudioManager: failed to play \(name).\(ext):", error)
        }
    }

    /// Stop immediately and release player.
    func stopBGM() {
        invalidateFade()
        player?.stop()
        player = nil
    }

    func pauseBGM() {
        invalidateFade()
        player?.pause()
    }

    func resumeBGM() {
        guard allowResume else { return }
        player?.play()
    }

    // MARK: - Fades

    private func invalidateFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    /// Linear fade to a target volume over `duration` seconds.
    private func fade(to target: Float, duration: TimeInterval, after: (() -> Void)? = nil) {
        guard let player else { after?(); return }

        invalidateFade()

        let clampedTarget = max(0, min(1, target))
        let fps: Double = 60
        let steps = max(1, Int(duration * fps))
        let start = player.volume
        let delta = clampedTarget - start
        var tick = 0

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] t in
            guard let self, let player = self.player else { t.invalidate(); return }
            tick += 1
            if tick >= steps {
                player.volume = clampedTarget
                t.invalidate()
                self.fadeTimer = nil
                after?()
                return
            }
            let progress = Float(tick) / Float(steps)
            // Optional ease-out curve; feels a bit nicer than linear:
            let eased = sin((progress * .pi) / 2)
            player.volume = start + delta * eased
        }
        fadeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Fade in from current volume to `baseVolume` and ensure playback.
    func fadeInAndPlay(duration: TimeInterval = 0.45) {
        guard allowResume else { return }
        guard player != nil else { return } // call playBGM(...) first if needed
        player?.prepareToPlay()
        player?.play()
        fade(to: baseVolume, duration: duration, after: nil)
    }

    /// Fade out to 0, then pause. Resets volume back to `baseVolume` for the next resume.
    func fadeOutAndPause(duration: TimeInterval = 0.35) {
        guard let player else { return }
        fade(to: 0, duration: duration) { [weak self] in
            player.pause()
            if let base = self?.baseVolume {
                player.volume = base
            }
        }
    }
}
