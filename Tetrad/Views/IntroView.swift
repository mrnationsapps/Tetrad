import SwiftUI

struct IntroView: View {
    // Env
    @EnvironmentObject var game: GameState
    @EnvironmentObject var levels: LevelsService

    // Nav
    @State private var navigateToGame = false
    @State private var navigateToLevels = false

    // Data
    @State private var achievements: [Achievement] = Achievement.all

    // Reward FX (Lottie)
    @State private var showCoinOverlay = false
    @State private var lastAwardedCoins = 0

//    // Toast gate
//    @State private var didShowRewardToastThisSession = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.softSandSat.ignoresSafeArea()

                // Main content
                VStack(spacing: 20) {
                    header
                    achievementsSection
                }

                // Lottie coin overlay
                rewardOverlayLayer
            }
            .safeAreaInset(edge: .bottom) { bottomCTA }
            .navigationDestination(isPresented: $navigateToGame) {
                ContentView()
                    .environmentObject(game)
            }
            .navigationDestination(isPresented: $navigateToLevels) {
                LevelsView()
                    .environmentObject(game)
            }
        }
        .onAppear {
            achievements = Achievement.all
            // (Toast removed — no session-gated reward prompt)
        }

    }
}

// MARK: - Chunks

private extension IntroView {
    var header: some View {
        VStack(spacing: 8) {
            Text("TETRAD")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .tracking(3)

            Text("Make 4 four-letter words, daily.")
                .font(.headline)
        }
        .foregroundStyle(Color.black)
        .padding(.top, 28)
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
            .foregroundStyle(Color.black)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(achievements) { ach in
                        AchievementRow(
                            achievement: ach,
                            isUnlocked: ach.isUnlocked(using: game),
                            onClaimed: { coins in
                                // Credit immediately, then play the coin overlay
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

            Button {
                game.startDailyRun()   // set mode = .daily and bootstrap today's run
                navigateToGame = true  // then navigate
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
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color.softSandSat.opacity(0.7))
    }

    @ViewBuilder
    var rewardOverlayLayer: some View {
        if showCoinOverlay {
            CoinRewardOverlay(
                isPresented: $showCoinOverlay,
                amount: lastAwardedCoins
            ) {
                // Optional: any follow-up after the Lottie finishes
                // e.g., ToastCenter.shared.show("Coins added to wallet")
            }
            .transition(.opacity)
            .zIndex(50)
        }
    }

    func unlockedCount() -> Int {
        achievements.filter { $0.isUnlocked(using: game) }.count
    }
}

// MARK: - Rows (file-private to this file)
struct AchievementRow: View {
    let achievement: Achievement
    let isUnlocked: Bool
    var onClaimed: (Int) -> Void

    @State private var claimed: Bool = false

    private var rewardAmount: Int { achievement.rewardCoins }
    private var claimKey: String { "ach.claimed.\(achievement.key)" }
    private var canClaim: Bool { isUnlocked && !claimed }
    private var isLockedRow: Bool { !isUnlocked }

    var body: some View {
        let core = rowCore(showCollectLabel: canClaim)

        Group {
            if canClaim {
                Button(action: claim) {
                    core
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel(Text("Collect \(rewardAmount) coins"))
            } else {
                core
            }
        }
        // shared card background
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .softRaised(corner: 12)
        )
        // ghost entire row when locked
        .opacity(isLockedRow ? 0.60 : 1.0)
        .saturation(isLockedRow ? 0.85 : 1.0)
        .grayscale(isLockedRow ? 0.20 : 0.0)
        .onAppear {
            claimed = UserDefaults.standard.bool(forKey: claimKey)
        }
    }

    private func claim() {
        UserDefaults.standard.set(true, forKey: claimKey)
        claimed = true
        onClaimed(rewardAmount)
    }

    @ViewBuilder
    private func rowCore(showCollectLabel: Bool) -> some View {
        HStack(spacing: 12) {
            // LEFT ICON:
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

            // TITLE + SUBTITLE
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

            // RIGHT SIDE: divider + “Collect!” when claimable
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
