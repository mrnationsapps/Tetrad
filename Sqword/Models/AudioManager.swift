//
//  AudioManager.swift
//  Sqword
//
//  Created by kevin nations on 10/25/25.
//
import AVFoundation

final class AudioManager {
    static let shared = AudioManager()
    private var player: AVAudioPlayer?

    private init() {}

    var isPlaying: Bool { player?.isPlaying ?? false }
    var isLoaded: Bool { player != nil }


    /// Play a looping background track from the app bundle.
    func playBGM(named name: String, ext: String = "mp3", volume: Float = 0.45, loop: Bool = true) {
        // If already playing this track, do nothing
        if let p = player, p.isPlaying { return }

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("⚠️ AudioManager: Missing resource \(name).\(ext)")
            return
        }

        do {
            // Keep it simple (no background audio session needed)
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = loop ? -1 : 0
            p.volume = volume
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            print("⚠️ AudioManager: failed to play \(name).\(ext):", error)
        }
    }

    /// Stop immediately (simple for now; we can add fade later)
    func stopBGM() {
        player?.stop()
        player = nil
    }
    
    func pauseBGM() { player?.pause() }
    func resumeBGM() { if let p = player, !p.isPlaying { p.play() } }
}

