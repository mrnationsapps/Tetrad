import SwiftUI

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

    
    var body: some View {
        ZStack {
            // ✅ Full-bleed background outside the NavigationStack
            NavigationStack {
                ZStack {
                    // (No background color here — keep it transparent)
                    VStack(spacing: 20) {
                        header
                        achievementsSection
                    }

                    // Lottie coin overlay
                    rewardOverlayLayer
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
                        withAnimation(.spring()) { showSettings = true }
                    } label: {
                        Image(systemName: "gearshape").imageScale(.medium)
                    }
                    .accessibilityLabel("Open Settings")
                    .buttonStyle(SoftRaisedPillStyle(height: 40))
                    .opacity(0.5)
                    .frame(width: 60)
                    .padding(.trailing, 10)
                    .offset(y: -20)
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
        .padding(.horizontal)
    }

    var bottomCTA: some View {
        VStack(spacing: 12) {
            Button {
                soundFX.playButton()
                navigateToLevels = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller").imageScale(.medium)
                    Text("Play").font(.title3).bold()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
            }
            .buttonStyle(SoftRaisedPillStyle(height: 52))

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

    func unlockedCount() -> Int {
        achievements.filter { $0.isUnlocked(using: game) }.count
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
