//
//  MusicCenter.swift
//  Sqword
//
//  Created by kevin nations on 10/25/25.
//
import SwiftUI

final class MusicCenter: ObservableObject {
    enum Zone { case none, menu, game }

    // Persisted user setting
    @Published var enabled: Bool = UserDefaults.standard.object(forKey: "musicEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "musicEnabled")
            apply()
        }
    }

    // Where the app currently is (menu or game)
    @Published var zone: Zone = .none { didSet { apply() } }

    func enterMenu() { zone = .menu }
    func enterGame() { zone = .game }

    /// Decide and apply playback
    private func apply() {
        switch (enabled, zone) {
        case (true, .menu):
            // resume or start if not loaded yet
            AudioManager.shared.resumeBGM()
            if !AudioManager.shared.isPlaying {
                AudioManager.shared.playBGM(named: "sqword-music")
            }
        default:
            AudioManager.shared.pauseBGM()
        }
    }
}

