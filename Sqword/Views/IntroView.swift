import SwiftUI
import Lottie 

struct IntroView: View {
    // Env
    @EnvironmentObject var game: GameState
    @EnvironmentObject var levels: LevelsService
    @EnvironmentObject private var music: MusicCenter

    // Nav
    @State private var navigateToGame = false
    @State private var navigateToLevels = false
    
    @State private var showSettings = false

    // Data
    @State private var achievements: [Achievement] = Achievement.all

    // Reward FX (Lottie)
    @State private var showCoinOverlay = false
    @State private var lastAwardedCoins = 0
    @AppStorage("ach.tutorial.completed") private var tutorialCompleted: Bool = false

    @StateObject private var soundFX = SoundEffects.shared
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    // Tutorial helpers
    @AppStorage("helper.settings.seen") private var settingsHelperSeen: Bool = false
    @AppStorage("helper.achievements.seen") private var achievementsHelperSeen: Bool = false
    @AppStorage("helper.play.seen") private var playHelperSeen: Bool = false
    @State private var showAchievementsHelper = false
    @State private var showSettingsHelper = true
    @State private var settingsButtonFrame: CGRect = .zero
    @State private var showPlayHelper = false
    @State private var playButtonFrame: CGRect = .zero

    
    var body: some View {
        ZStack {
            // ✅ Full-bleed background outside the NavigationStack
            NavigationStack {
                ZStack {
                    // (No background color here – keep it transparent)
                    VStack(spacing: 20) {
                        header
                        achievementsSection
                    }

                    // Lottie coin overlay
                    rewardOverlayLayer
                    
                    // Settings helper overlay
                    if showSettingsHelper && !settingsHelperSeen {
                        settingsHelperOverlay
                    }
                    
                    // Achievements helper overlay
                    if showAchievementsHelper && !achievementsHelperSeen {
                        achievementsHelperOverlay
                    }
                    
                    // Play helper overlay
                    if showPlayHelper && !playHelperSeen {
                        playHelperOverlay
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                .safeAreaInset(edge: .bottom) { bottomCTA }
                .navigationDestination(isPresented: $navigateToGame) {
                    ContentView()
                        .environmentObject(game)
                }
                .navigationDestination(isPresented: $navigateToLevels) {
                    LevelsView()
                        .environmentObject(game)
                }

                // Belt & suspenders nav appearance
                .onAppear {
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = UIColor(Color.softSandSat)
                    appearance.backgroundEffect = nil
                    appearance.shadowColor = .clear
                    appearance.shadowImage = UIImage()

                    let nav = UINavigationBar.appearance()
                    nav.standardAppearance   = appearance
                    nav.compactAppearance    = appearance
                    nav.scrollEdgeAppearance = appearance
                    nav.isTranslucent        = false

                    // Legacy shims
                    nav.setBackgroundImage(UIImage(), for: .default)
                    nav.shadowImage = UIImage()
                }
                
//                .onAppear { music.enterMenu() }

            }
            .background {
                Image("Sqword-Splash")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }

        .onAppear {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.softSandSat)
            appearance.backgroundEffect = nil
            appearance.shadowColor = .clear      // iOS 15+
            
            let nav = UINavigationBar.appearance()
            nav.standardAppearance   = appearance
            nav.compactAppearance    = appearance
            nav.scrollEdgeAppearance = appearance
            nav.isTranslucent        = false

            // Legacy shims that still matter on some versions
            nav.setBackgroundImage(UIImage(), for: .default)
            nav.shadowImage = UIImage()
            
            achievements = Achievement.all
        }
        .settingsOverlay(isPresented: $showSettings)
        .onPreferenceChange(SettingsButtonPositionKey.self) { frame in
            settingsButtonFrame = frame
        }
        
        .onChange(of: showSettings) { newValue in
            if !newValue && !achievementsHelperSeen {  // Settings just closed
                showAchievementsHelper = true
            }
        }

    }

}

// MARK: - Chunks

private extension IntroView {
    var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Text("SQWORD")
                    .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 50 : 30, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundColor(.white)
                    .opacity(0.5)
                    .offset(y: -20)

                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring()) {
                            showSettings = true
                            showSettingsHelper = false
                            settingsHelperSeen = true
                        }
                    } label: {
                        Image(systemName: "gearshape").imageScale(.medium)
                    }
                    .accessibilityLabel("Open Settings")
                    .buttonStyle(SoftRaisedPillStyle(height: 40))
                    .opacity(0.5)
                    .frame(width: 60)
                    .padding(.trailing, 10)
                    .offset(y: -20)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    settingsButtonFrame = geo.frame(in: .global)
                                }
                                .onChange(of: geo.frame(in: .global)) { newFrame in
                                    settingsButtonFrame = newFrame
                                }
                        }
                    )
                }

            }
            .safeAreaPadding(.top)
            .padding(.top, 0)


            Text("Make 4 four-letter words, daily.")
                .font(.headline)
        }
        .foregroundStyle(Color.white)
        .padding(.top, 0)

    }

    var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements Unlocked!")
                    .font(.title3).bold()
                Spacer()
                Text("\(unlockedCount())/\(achievements.count)")
                    .font(.subheadline)
            }
            .foregroundStyle(Color.white)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(achievements) { ach in
                        AchievementRow(
                            achievement: ach,
                            isUnlocked: ach.isUnlocked(using: game),
                            onClaimed: { coins in
                                guard coins > 0 else { return }
                                levels.addCoins(coins)
                                lastAwardedCoins = coins
                                showCoinOverlay = true
                            }
                        )
                        .environmentObject(levels)
                        .environmentObject(game)
                        .onAppear {
                            // Hide achievements helper and show play helper
                            if showAchievementsHelper {
                                showAchievementsHelper = false
                                achievementsHelperSeen = true
                                // Show play helper after a brief delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if !playHelperSeen {
                                        showPlayHelper = true
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.softgreen)
                    .softRaised(corner: 16)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal)    }

    var bottomCTA: some View {
        VStack(spacing: 12) {
            Button {
                soundFX.playButton()
                navigateToLevels = true
                showPlayHelper = false  // Hide helper
                playHelperSeen = true   // Never show again
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller").imageScale(.medium)
                    Text("Play").font(.title3).bold()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
            }
            .buttonStyle(SoftRaisedPillStyle(height: 52))
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            playButtonFrame = geo.frame(in: .global)
                        }
                        .onChange(of: geo.frame(in: .global)) { newFrame in
                            playButtonFrame = newFrame
                        }
                }
            )
            
            if tutorialCompleted {
                Button {
                    soundFX.playButton()
                    game.startDailyRun()
                    navigateToGame = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill").imageScale(.medium)
                        Text("Play Daily Puzzle").font(.title3).bold()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(SoftRaisedPillStyle(height: 52))
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    var rewardOverlayLayer: some View {
        if showCoinOverlay {
            CoinRewardOverlay(
                isPresented: $showCoinOverlay,
                amount: lastAwardedCoins
            ) {
                // optional follow-up
            }
            .transition(.opacity)
            .zIndex(50)
        }
    }

    // Helper Lottie vars /////////
    
    @ViewBuilder
    var playHelperOverlay: some View {
        if playButtonFrame != .zero {
            LottieView(
                name: "Play_lottie",
                loop: .loop,
                speed: 1.0
            )
            .scaleEffect(0.4)
//            .frame(width: 120, height: 120)
            .position(
                x: playButtonFrame.midX + 50,
                y: playButtonFrame.midY - 180
            )
            .allowsHitTesting(false)
            .zIndex(100)
        }
    }
    
    @ViewBuilder
    var settingsHelperOverlay: some View {
        LottieView(
            name: "Settings_lottie",
            loop: .loop
        )
        .scaleEffect(0.3)
        .position(
            x: settingsButtonFrame.maxX  - (isPad ? 180 : 140),
            y: settingsButtonFrame.minY + (isPad ? 90 : 0)
//            y: settingsButtonFrame.minY + 90
        )
        .allowsHitTesting(false)
        .zIndex(100)
    }
    
    @ViewBuilder
    var achievementsHelperOverlay: some View {
        LottieView(
            name: "Achievements_lottie",
            loop: .loop,
            speed: 1.0
        )
        .scaleEffect(0.5)
//        .frame(width: 120, height: 120)
        .position(
            x: UIScreen.main.bounds.width - (isPad ? 200 : 130),  // Screen right
            y: UIScreen.main.bounds.height / 2    // Vertically centered
        )
        .allowsHitTesting(false)
        .zIndex(100)
    }

    func unlockedCount() -> Int {
        achievements.filter { $0.isUnlocked(using: game) }.count
    }
}

// MARK: - Preference Key
struct SettingsButtonPositionKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Rows (unchanged)
struct AchievementRow: View {
    let achievement: Achievement
    let isUnlocked: Bool
    var onClaimed: (Int) -> Void

    @State private var claimed: Bool = false
    @StateObject private var soundFX = SoundEffects.shared

    private var rewardAmount: Int { achievement.rewardCoins }
    private var claimKey: String { "ach.claimed.\(achievement.key)" }
    private var canClaim: Bool { isUnlocked && !claimed }
    private var isLockedRow: Bool { !isUnlocked }

    var body: some View {
        let core = rowCore(showCollectLabel: canClaim)

        Group {
            if canClaim {
                Button(action: claim) { core }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel(Text("Collect \(rewardAmount) coins"))
            } else {
                core
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .softRaised(corner: 12)
        )
        .opacity(isLockedRow ? 0.60 : 1.0)
        .saturation(isLockedRow ? 0.85 : 1.0)
        .grayscale(isLockedRow ? 0.20 : 0.0)
        .onAppear {
            claimed = UserDefaults.standard.bool(forKey: claimKey)
        }
    }

    private func claim() {
        soundFX.playChestOpenSequence()
        UserDefaults.standard.set(true, forKey: claimKey)
        claimed = true
        onClaimed(rewardAmount)
    }

    @ViewBuilder
    private func rowCore(showCollectLabel: Bool) -> some View {
        HStack(spacing: 12) {
            if claimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.green)
                    .frame(width: 24, height: 24)
                    .padding(.leading, 2)
                    .accessibilityHidden(true)
            } else if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .padding(.leading, 2)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                    .lineLimit(1)
                Text(achievement.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if showCollectLabel {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 1)

                    Text("Collect!")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .padding(.leading, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 64, alignment: .trailing)
                }
                .overlay(alignment: .leading) {
                    GeometryReader { gr in
                        Rectangle()
                            .fill(Color.primary.opacity(0.10))
                            .frame(width: 1, height: gr.size.height)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(10)
        .contentShape(Rectangle())
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
