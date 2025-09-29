import SwiftUI

struct LevelsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var game: GameState
    @EnvironmentObject var levels: LevelsService

    // Navigation
    @State private var navigateToLevel = false
    @State private var levelWorld: World?

    // Alerts
    @State private var showInsufficientCoins = false
    @State private var showConfirmUnlock = false
    @State private var pendingUnlockWorld: World?

    var body: some View {
        VStack(spacing: 16) {
            header
            worldList
            Spacer(minLength: 8) // small breathing room where the footer used to be
        }
        .padding(.horizontal)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left").imageScale(.medium)
                        Text("Back")
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(SoftRaisedPillStyle(height: 36))
            }

            ToolbarItem(placement: .principal) {
                Text("TETRAD")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .tracking(2)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle")
                        .imageScale(.large)
                    Text("\(levels.coins)")
                        .font(.headline)
                }
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .softRaisedCapsule()
            }
        }
        // Not enough coins
        .alert("Not enough coins", isPresented: $showInsufficientCoins) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You don’t have enough coins to unlock \(levels.selectedWorld.name).")
        }
        // Confirm unlock
        .alert("Unlock \(pendingUnlockWorld?.name ?? "this world")?",
               isPresented: $showConfirmUnlock) {
            Button("Cancel", role: .cancel) { pendingUnlockWorld = nil }
            Button("Unlock & Play", role: .none) {
                guard let world = pendingUnlockWorld else { return }
                // Spend and reorder (LevelsService handles persistence)
                let _ = levels.unlockSelectedIfPossible()
                // Auto-play right after unlocking
                levelWorld = world
                navigateToLevel = true
                pendingUnlockWorld = nil
            }
        } message: {
            let cost = pendingUnlockWorld?.unlockCost ?? 0
            Text("Spend \(cost) coins to unlock and start playing.")
        }
        // Navigate into a level
        .navigationDestination(isPresented: $navigateToLevel) {
            if let world = levelWorld {
                LevelPlayView(world: world)
                    .environmentObject(game)
            }
        }
    }

    private struct WorldCard: View {
        let world: World
        let selected: Bool
        let unlocked: Bool
        let coins: Int
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                ZStack {
                    // Artwork or placeholder
                    if let art = world.artName, UIImage(named: art) != nil {
                        Image(art)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [.blue.opacity(0.35), .purple.opacity(0.35)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    }

                    // Title & cost badge
                    VStack {
                        HStack {
                            Spacer()
                            if !unlocked {
                                HStack(spacing: 6) {
                                    Image(systemName: "dollarsign.circle.fill").imageScale(.small)
                                    Text("\(world.unlockCost)").font(.footnote).bold()
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                        .padding(8)

                        Spacer()

                        Text(world.name)
                            .font(.headline).bold()
                            .shadow(radius: 2)
                            .padding(.bottom, 10)
                    }
                    .foregroundStyle(.white)

                    // Lock overlay
                    if !unlocked {
                        Color.black.opacity(0.35)
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    // Selection ring
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selected ? Color.accentColor : .clear, lineWidth: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .softRaised(corner: 16, pressed: selected)   // uses your SoftRaised style
            }
            .buttonStyle(.plain)
        }
    }


    // MARK: Header spacer (toolbar holds the actual header UI)
    private var header: some View {
        Color.clear.frame(height: 1)
    }

    // MARK: World list (3 rows, horizontal scroll)
    private var worldList: some View {
        let cardSize = CGSize(width: 150, height: 200)
        let rowSpacing: CGFloat = 14
        let rows: [GridItem] = [
            GridItem(.fixed(cardSize.height), spacing: rowSpacing, alignment: .top),
            GridItem(.fixed(cardSize.height), spacing: rowSpacing, alignment: .top),
            GridItem(.fixed(cardSize.height), spacing: rowSpacing, alignment: .top)
        ]

        return VStack(alignment: .leading, spacing: 8) {
            Text("Worlds")
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: rows, alignment: .top, spacing: 14) {
                    ForEach(levels.worlds) { world in
                        WorldCard(
                            world: world,
                            selected: world.id == levels.selectedWorldID,
                            unlocked: levels.isUnlocked(world),
                            coins: levels.coins,
                            onTap: {
                                levels.select(world)
                                if levels.isUnlocked(world) {
                                    levelWorld = world
                                    navigateToLevel = true
                                } else if levels.coins >= world.unlockCost {
                                    pendingUnlockWorld = world
                                    showConfirmUnlock = true
                                } else {
                                    showInsufficientCoins = true
                                }
                            }
                        )
                        .frame(width: cardSize.width, height: cardSize.height)
                    }
                }
                // total height = 3 rows + 2 row gaps
                .frame(height: (cardSize.height * 3) + (rowSpacing * 2))
                .padding(.vertical, 6)
            }
        }
    }

}
