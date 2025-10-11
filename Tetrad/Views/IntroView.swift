import SwiftUI

struct IntroView: View {
    @EnvironmentObject var game: GameState
    @State private var navigateToGame = false
    @State private var achievements: [Achievement] = Achievement.all
    @State private var navigateToLevels = false


    var body: some View {
        NavigationStack {
            
            ZStack{
                Color.softSandSat.ignoresSafeArea()

                // CONTENT (header + achievements that fills space)
                VStack(spacing: 20) {
                    
                    // HEADER (fixed)
                    VStack(spacing: 8) {
                        Text("TETRAD")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .tracking(3)
                        
                        Text("Make 4 four-letter words, daily.")
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

                        // ScrollView padded as a unit so background hugs it
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(achievements) { ach in
                                    AchievementRow(
                                        achievement: ach,
                                        isUnlocked: ach.isUnlocked(using: game)
                                    )
                                }
                            }
                            .padding(.bottom, 12) // space after last row
                        }
                        .padding(12) // <— move padding outside content
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.softgreen)
                                .softRaised(corner: 16)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16)) // keep scrollers/ink inside
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .padding(.horizontal)
                }
            }

            // Bottom CTAs pinned to safe area

            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    // PLAY (Levels)
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

                    // Play Daily Puzzle
                    Button {
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
                    .padding(.bottom, 4) // a tiny buffer above the home bar
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .background(Color.softSandSat.opacity(0.7))
            }

            .navigationDestination(isPresented: $navigateToGame) {
                ContentView().environmentObject(game)
            }
            .navigationDestination(isPresented: $navigateToLevels) {
                LevelsView()                             // 👈 NEW screen
                    .environmentObject(game)
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
                    .fill(Color.softSandSat)
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
                .fill(Color.softSandBright)
                .softRaised(corner: 12)
        )
        // Keep the locked ones a bit subdued
        .grayscale(isUnlocked ? 0 : 1)
        .opacity(isUnlocked ? 1 : 0.85)
    }
}
