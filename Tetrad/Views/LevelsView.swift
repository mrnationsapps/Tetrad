import SwiftUI

private enum WorldRoute: Hashable {
    case tutorial(World.ID)
    case level(World.ID)
}

struct LevelsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var game: GameState
    @EnvironmentObject var levels: LevelsService
    @EnvironmentObject var boosts: BoostsService

    // Navigation
    @State private var navigateToLevel = false
    @State private var levelWorld: World?

    // Alerts
    @State private var showInsufficientCoins = false
    @State private var showConfirmUnlock = false
    @State private var pendingUnlockWorld: World?

    // Wallet sheet state
    @State private var walletExpanded: Bool = false      // on/off
    @State private var walletExpansion: CGFloat = 0      // 0…1 progress (for backdrop opacity)
    @GestureState private var walletDrag: CGFloat = 0    // live drag delta (+down, −up)
    @State private var coinPulse: Bool = false

    var body: some View {
        let backdropVisible = walletExpansion > 0.01

        // MAIN LAYOUT
        let main = ZStack {
            // content
            VStack(spacing: 16) {
                header
                worldList
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.bottom)  // nudge vertical
                Spacer(minLength: 8)
            }
            .padding(.horizontal)
        }

        return main
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


            }
        
            // alerts
            .alert("Not enough coins", isPresented: $showInsufficientCoins) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You don’t have enough coins to unlock \(levels.selectedWorld.name).")
            }
            .alert("Unlock \(pendingUnlockWorld?.name ?? "this world")?",
                   isPresented: $showConfirmUnlock) {
                Button("Cancel", role: .cancel) { pendingUnlockWorld = nil }
                Button("Unlock & Play") {
                    guard let world = pendingUnlockWorld else { return }
                    _ = levels.unlockSelectedIfPossible()
                    levelWorld = world
                    navigateToLevel = true
                    pendingUnlockWorld = nil
                }
            } message: {
                let cost = pendingUnlockWorld?.unlockCost ?? 0
                Text("Spend \(cost) coins to unlock and start playing.")
            }
            .navigationDestination(isPresented: $navigateToLevel) {
                if let world = levelWorld {
                    LevelPlayView(world: world)
                        .environmentObject(game)
                }
            }
            // start collapsed (no jump)
            .onChange(of: levels.coins) { _, _ in
                coinPulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { coinPulse = false }
            }

            .withFooterPanels(
                coins: levels.coins,
                boostsAvailable: boosts.remaining,
                isInteractable: true,                 // footer is always active on Worlds
                disabledStyle: .standard,
                boostsPanel: { _ in WorldsBoostsPanel() },     // read-only note on this screen
                walletPanel: { dismiss in WorldsWalletPanel(dismiss: dismiss) }
            )
    }

    // MARK: Header spacer (toolbar holds the actual header UI)
    private var header: some View { Color.clear.frame(height: 1) }

    // MARK: World list (3 rows, horizontal scroll)
    private var worldList: some View {
        let cardSize = CGSize(width: 150, height: 194)
        let rowSpacing: CGFloat = 8
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
                LazyHGrid(rows: rows, alignment: .top, spacing: 8) {
                    ForEach(levels.worlds) { world in
                        if levels.isUnlocked(world) {
                            NavigationLink {
                                destinationView(for: world)      // Tutorial vs normal
                                    .onAppear { levels.select(world) } // keep selection highlight
                            } label: {
                                WorldCard(
                                    world: world,
                                    selected: world.id == levels.selectedWorldID,
                                    unlocked: true,
                                    coins: levels.coins
                                    // onTap omitted → nil → no internal gesture
                                )
                                .frame(width: cardSize.width, height: cardSize.height)
                            }
                            .buttonStyle(.plain) // keep label look

                        } else {
                            Button {
                                levels.select(world)
                                if levels.coins >= world.unlockCost {
                                    pendingUnlockWorld = world
                                    showConfirmUnlock = true
                                } else {
                                    showInsufficientCoins = true
                                }
                            } label: {
                                WorldCard(
                                    world: world,
                                    selected: world.id == levels.selectedWorldID,
                                    unlocked: false,
                                    coins: levels.coins
                                    // outer Button handles the tap
                                )
                                .frame(width: cardSize.width, height: cardSize.height)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: (cardSize.height * 3) + (rowSpacing * 2))
                .padding(.vertical, 8)
                .zIndex(1) // keep the grid above any decorative overlays
            }
        }
    }


    @ViewBuilder
    private func destinationView(for world: World) -> some View {
        if world.isTutorial {
            TutorialWorldView(world: world)
                .environmentObject(levels)
        } else {
            LevelPlayView(world: world)
                .environmentObject(game)
                .environmentObject(levels)
        }
    }

    
    // MARK: Small pill components
    @ViewBuilder
    private func walletBoostPill(icon: String, title: String, cost: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill").imageScale(.small)
                    Text("\(cost)").font(.caption2).monospacedDigit()
                }.opacity(0.9)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func walletIAPPill(amount: Int, price: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill").imageScale(.small)
                    Text("+\(amount)").font(.caption).monospacedDigit()
                }
                Text(price).font(.caption2).opacity(0.9)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions
    private func setWallet(_ expanded: Bool, animated: Bool = true) {
        if expanded {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        let anim: Animation? = animated ? .spring(response: 0.35, dampingFraction: 0.9) : nil
        withAnimation(anim) {
            walletExpanded = expanded
            walletExpansion = expanded ? 1 : 0
        }
    }

    private func toggleWallet() { setWallet(!walletExpanded) }

    private func buyRevealBoost(cost: Int, count: Int = 1) {
        if levels.coins >= cost {
            levels.addCoins(-cost)
            boosts.grant(count: count)
        } else {
            showInsufficientCoins = true
        }
    }

    private func simulateIAPPurchase(coins: Int) {
        levels.addCoins(coins)
    }
}

// MARK: - World Card
private struct WorldCard: View {
    let world: World
    let selected: Bool
    let unlocked: Bool
    let coins: Int
    var onTap: (() -> Void)? = nil   // optional: when nil, no gesture is attached

    var body: some View {
        let card = ZStack {
            if let art = world.artName, UIImage(named: art) != nil {
                Image(art).resizable().scaledToFill().clipped()
            } else {
                LinearGradient(
                    colors: [.blue.opacity(0.35), .purple.opacity(0.35)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }

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

            if !unlocked {
                Color.black.opacity(0.35)
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
            }

            RoundedRectangle(cornerRadius: 16)
                .stroke(selected ? Color.accentColor : .clear, lineWidth: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .softRaised(corner: 16, pressed: selected)
        .contentShape(RoundedRectangle(cornerRadius: 16))

        Group {
            if let onTap {
                card.onTapGesture(perform: onTap)
                    .accessibilityAddTraits(.isButton)
            } else {
                card // no gesture; lets outer NavigationLink/Button handle taps
            }
        }
        .accessibilityLabel(Text(world.name))
    }
}


