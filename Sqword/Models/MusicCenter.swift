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
    @Published var zone: Zone = .none {
        didSet { apply() }
    }

    // MARK: - Debug tracking
    private(set) var lastCaller: String = "unknown"

    /// Explicitly re-apply current state to the audio layer (handy on scenePhase changes).
    func refresh(_ src: String = #fileID) {
        lastCaller = src
        log("refresh")
        apply()
    }

    // MARK: - Zone APIs (with caller logging)
    func enterMenu(_ src: String = #fileID) {
        lastCaller = src
        log("enterMenu")
        zone = .menu
    }

    func enterGame(_ src: String = #fileID) {
        lastCaller = src
        log("enterGame")
        zone = .game
    }

    // MARK: - Router
    /// Decide and apply playback
    private func apply() {
        switch (enabled, zone) {
        case (true, .menu):
            AudioManager.shared.allowResume = true
            if !AudioManager.shared.isLoaded {
                AudioManager.shared.playBGM(named: "sqword-music", volume: 0.45)
            }
            AudioManager.shared.fadeInAndPlay(duration: 0.45)

        default:
            AudioManager.shared.allowResume = false
            AudioManager.shared.fadeOutAndPause(duration: 0.35)
        }
    }


    // MARK: - Logging helper
    private func log(_ msg: String) {
        #if DEBUG
        print("[Music] \(msg)  (lastCaller: \(lastCaller))")
        #endif
    }
}
