//
//  SoundEffects.swift
//  Sqword
//
//  Created by kevin nations on 11/2/25.
//

//  Manages short sound effects (buttons, achievements, etc.)
//  Works alongside AudioManager (which handles background music)
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class SoundEffects: ObservableObject {
    static let shared = SoundEffects()
    
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: soundEnabledKey)
        }
    }
    
    private let soundEnabledKey = "settings.soundEffects.enabled"
    private var players: [String: AVAudioPlayer] = [:]
    
    private init() {
        // Load saved preference (default: enabled)
        self.isEnabled = UserDefaults.standard.object(forKey: soundEnabledKey) as? Bool ?? true
        
        // Configure audio session to mix with music
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            // .ambient with .mixWithOthers allows sound effects to play alongside background music
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ SoundEffects: Failed to configure audio session: \(error)")
        }
    }
    
    /// Play a sound effect once
    func play(_ soundName: String, volume: Float = 1.0) {
        guard isEnabled else { return }
        
        // Try to reuse existing player, or create new one
        if let player = players[soundName] {
            player.currentTime = 0
            player.volume = volume
            player.play()
        } else {
            // Create new player for this sound
            guard let url = Bundle.main.url(forResource: soundName, withExtension: nil) else {
                print("⚠️ Sound file not found: \(soundName)")
                return
            }
            
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.volume = volume
                players[soundName] = player
                player.play()
            } catch {
                print("⚠️ Failed to play sound \(soundName): \(error)")
            }
        }
    }
    
    /// Preload sounds for better performance (optional, call during app startup)
    func preloadSounds(_ soundNames: [String]) {
        for soundName in soundNames {
            guard players[soundName] == nil else { continue }
            guard let url = Bundle.main.url(forResource: soundName, withExtension: nil) else {
                continue
            }
            
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                players[soundName] = player
            }
        }
    }
}

// MARK: - Common Sound Effects
extension SoundEffects {
    func playButton() { play("PlayButton.m4a", volume: 0.5) }
    func WonLevel() { play("WonLevel.m4a", volume: 0.5) }
    func Chest_01() { play("Chest_01.m4a", volume: 0.5) }
    func Coins_01() { play("Coins_01.m4a", volume: 0.5) }
    func Coins_02() { play("Coins_02.m4a", volume: 0.5) }
    func EnterLevel() { play("EnterLevel.m4a", volume: 0.9) }
    func WorldWordFound() { play("WorldWordFound.m4a", volume: 0.7) }
    func playChestOpenSequence() {
        play("PlayButton.m4a", volume: 0.9)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.play("ChestOpen.m4a", volume: 0.8)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.play("Coins_02.m4a", volume: 0.8)
        }
    }

    
    // Add more convenience methods as you add more sounds:
    // func playAchievement() { play("achievement.m4a") }
    // func playTilePlacement() { play("tile_place.m4a", volume: 0.3) }
    // func playLevelComplete() { play("level_complete.m4a") }
}
