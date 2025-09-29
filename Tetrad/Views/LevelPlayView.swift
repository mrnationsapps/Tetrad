import SwiftUI

struct LevelPlayView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var levels: LevelsService

    let world: World

    @State private var didStart = false
    @State private var showWin = false
    @State private var didAwardCoins = false
    @State private var par: Int = 0

    var body: some View {
        ZStack {
            // Reuse board UI (skip Daily bootstrap; suppress Daily win/share UI)
            ContentView(skipDailyBootstrap: true, enableDailyWinUI: false)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Back
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").imageScale(.medium)
                        // Text("Worlds")
                    }
                }
                .buttonStyle(SoftRaisedPillStyle(height: 36))
            }

            // Level badge title
            ToolbarItem(placement: .principal) {
                Text("\(world.name) | L\(levels.levelIndex(for: world) + 1)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .tracking(1.5)
            }

            // Coins (no moves here)
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                    Text("\(levels.coins)")
                        .font(.headline)
                        .monospacedDigit()
                }
                .softRaisedCapsule()
            }
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            startNewSession()
        }
        .onChange(of: game.solved) { _, isSolved in
            if isSolved && game.isLevelMode {
                withAnimation(.spring()) { showWin = true }
            }
        }
        // Win overlay
        .overlay {
            if showWin {
                Color.black.opacity(0.25).ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 14) {
                    Text("You got it!").font(.title).bold()

                    // payout (no moves shown to user)
                    let payout = levels.rewardCoins(for: game.moveCount, par: par)

                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                        if payout.bonus > 0 {
                            Text("+$\(payout.total)  (+$\(payout.bonus) bonus)")
                                .font(.headline)
                        } else {
                            Text("+$\(payout.total)").font(.headline)
                        }
                    }
                    .foregroundStyle(.secondary)

                    let hasNext = levels.hasNextLevel(for: world)

                    if hasNext {
                        // Quit | Continue when another level exists
                        HStack(spacing: 10) {
                            // Quit: award coins, return to Worlds (no advance)
                            Button {
                                awardCoinsOnce(payout.total)
                                dismiss()
                            } label: {
                                Text("Quit")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SoftRaisedPillStyle(height: 48))

                            // Continue: award coins, advance, start next level
                            Button {
                                awardCoinsOnce(payout.total)
                                levels.advance(from: world)
                                showWin = false
                                startNewSession()  // loads next level (new seed)
                            } label: {
                                Text("Continue")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SoftRaisedPillStyle(height: 48))
                        }
                    } else {
                        // Final level: single Continue back to Worlds
                        Button {
                            awardCoinsOnce(payout.total)
                            dismiss()
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SoftRaisedPillStyle(height: 48))
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Helpers
    private func startNewSession() {
        let idx  = levels.levelIndex(for: world)
        par      = levels.levelPar(for: world, levelIndex: idx)
        let seed = levels.seed(for: world, levelIndex: idx)

        game.startLevelSession(seed: seed, dictionaryID: world.dictionaryID)

        showWin = false
        didAwardCoins = false
    }

    private func awardCoinsOnce(_ amount: Int) {
        guard !didAwardCoins else { return }
        didAwardCoins = true
        levels.addCoins(amount)
    }
}
