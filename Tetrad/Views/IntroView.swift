import SwiftUI

struct IntroView: View {
    @EnvironmentObject var game: GameState
    @State private var navigateToGame = false
    @State private var achievements: [Achievement] = Achievement.all

    var body: some View {
        NavigationStack {
            // CONTENT (header + achievements that fills space)
            VStack(spacing: 20) {
                // HEADER (fixed)
                VStack(spacing: 8) {
                    Text("TETRAD")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .tracking(3)

                    Text("Make 8 four-letter words, daily.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)

                // ACHIEVEMENTS (only this scrolls; expands to available space)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Achievements Unlocked!")
                            .font(.title3).bold()
                        Spacer()
                        Text("\(unlockedCount())/\(achievements.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(achievements) { ach in
                                AchievementRow(
                                    achievement: ach,
                                    isUnlocked: ach.isUnlocked(using: game)
                                )
                            }
                        }
                        .padding(12)
                    }
                    // Soft Raised container instead of thinMaterial
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.clear)
                            .softRaised(corner: 16)
                    )
                    .frame(maxHeight: .infinity, alignment: .top) // fills remaining space
                }
                .padding(.horizontal)
            }
            // Bottom CTA pinned to safe area
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Button {
                        navigateToGame = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill").imageScale(.medium)
                            Text("Play Daily Puzzle")
                                .font(.title3).bold()
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(SoftRaisedPillStyle(height: 52))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .background(.ultraThinMaterial) // subtle separation, safe-area aware
            }
            .navigationDestination(isPresented: $navigateToGame) {
                ContentView().environmentObject(game)
            }
        }
        .onAppear { achievements = Achievement.all }
    }

    private func unlockedCount() -> Int {
        achievements.filter { $0.isUnlocked(using: game) }.count
    }
}

// MARK: - Row (Soft Raised)
private struct AchievementRow: View {
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon tile (soft raised 44x44)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)
                    .softRaised(corner: 10)

                Image(systemName: achievement.symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isUnlocked ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline).bold()
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                Text(achievement.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .opacity(0.6)
            }
        }
        .padding(10)
        // Soft Raised card background (corner 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .softRaised(corner: 12)
        )
        // Keep the locked ones a bit subdued
        .grayscale(isUnlocked ? 0 : 1)
        .opacity(isUnlocked ? 1 : 0.85)
    }
}
