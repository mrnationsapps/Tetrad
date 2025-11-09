//
//  WalletPanelView.swift
//  Sqword
//
//  Buy Boosts (Reveal ×1 / Clarity ×1, 5 coins each)
//  Get Coins via IAP (coins_50 / coins_200) – left-aligned, fixed pill width (90×48)
//

import SwiftUI

struct WalletPanelView: View {
    @EnvironmentObject private var levels: LevelsService
    @EnvironmentObject private var boosts: BoostsService
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var store: IAPManager

    @State private var showToast = false
    @State private var toastText = ""
    @StateObject private var soundFX = SoundEffects.shared


    // Back-compat with call sites like: WalletPanelView(dismiss: dismiss)
    var dismiss: (() -> Void)? = nil

    // Optional external control (e.g., to ghost while another panel is active)
    var isDisabled: Bool = false

    @State private var showInsufficientCoins = false
    
    // Coin chest animation state (passed to parent)
    @Binding var showCoinOverlay: Bool
    @Binding var pendingRewardCoins: Int
    
    var dismissWalletExplainHelper: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            // CLAIM REWARDS (only if unclaimed achievements exist)
            if !Achievement.unclaimed(using: game).isEmpty {
                claimRewardsButton
            }

            // BUY BOOSTS (coin → boost conversion)
            buyBoostsSection

            // GET COINS (StoreKit wired)
            getCoinsSection
        }
        .padding(.vertical, 4)
        .alert("Not enough coins", isPresented: $showInsufficientCoins) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You don't have enough coins for that boost.")
        }
        // ✅ Quick success toast
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastText)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(radius: 6, y: 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showToast)
    }

    private var header: some View {
        HStack {
            Label("Wallet", systemImage: "creditcard")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                Text("\(levels.coins)").font(.headline).monospacedDigit()
            }
        }
    }

    // MARK: - Claim Rewards Button
    private var claimRewardsButton: some View {
        Button {
            // Calculate total rewards before claiming
            soundFX.playChestOpenSequence()
            let unclaimed = Achievement.unclaimed(using: game)
            let totalCoins = unclaimed.reduce(0) { $0 + $1.rewardCoins }
            
            guard totalCoins > 0 else { return }
            
            // Set up the animation
            pendingRewardCoins = totalCoins
            
            // Claim immediately (marks as claimed, adds coins)
            let claimed = Achievement.claimAll(using: game, levels: levels)
            
            // Show the coin chest animation
            if claimed > 0 {
                showCoinOverlay = true
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .imageScale(.medium)
                Text("Claim Rewards")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.green, Color.green.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.green.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Buy Boosts (Reveal ×1 / Clarity ×1)
    private var buyBoostsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Buy Boosts")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                // REVEAL
                Button(action: {
                    soundFX.Coins_01()
                    dismissWalletExplainHelper?()
                    buy(kind: .reveal, cost: 5) }) {
                    walletBoostPill(
                        icon: "wand.and.stars",
                        title: "Reveal ×1",
                        cost: 5,
                        owned: boosts.revealRemaining
                    )
                }
                .buttonStyle(.plain)

                // CLARITY
                Button(action: {
                    soundFX.Coins_01()
                    dismissWalletExplainHelper?() 
                    buy(kind: .clarity, cost: 5) }) {
                    walletBoostPill(
                        icon: "eye",
                        title: "Clarity ×1",
                        cost: 5,
                        owned: boosts.clarityRemaining
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func buy(kind: BoostsService.BoostKind, cost: Int) {
        if levels.coins >= cost {
            levels.addCoins(-cost)
            boosts.grant(count: 1, kind: kind)

            // Ensure achievement total increments
            game.noteBoostPurchased(count: 1)

            // Quick toast feedback; panel remains open
            switch kind {
            case .reveal:  toastText = "+1 Reveal"
            case .clarity: toastText = "+1 Clarity"
            }
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                showToast = false
            }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } else {
            showInsufficientCoins = true
        }
    }

    private func toast(_ text: String) {
        toastText = text
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { showToast = false }
    }

    // MARK: - Get Coins (IAP: coins_50 / coins_200)
    private var getCoinsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Get Coins", systemImage: "dollarsign.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Fixed pill sizing (left-aligned, no stretching)
            let pillWidth: CGFloat = 90
            let pillHeight: CGFloat = 48
            let pillSpacing: CGFloat = 40

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: pillWidth, maximum: pillWidth), spacing: pillSpacing)
                ],
                alignment: .leading,
                spacing: pillSpacing
            ) {
                ForEach([CoinProduct.coins50, .coins200]) { sku in
                    let product = store.products[sku]
                    let isBusy = (store.purchasing == sku)

                    Button {
                        Task {
                            await store.purchase(sku) { amount in
                                levels.addCoins(amount)
                                toast("+\(amount) coins")
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                            }
                        }
                    } label: {
                        ZStack {
                            VStack(spacing: 4) {
                                Text("+\(sku.coinAmount) coins")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                // Localized price if loaded; fallback while products load
                                Text(product?.displayPrice ?? (sku == .coins50 ? "$0.99" : "$2.99"))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: pillWidth, height: pillHeight, alignment: .center)

                            if isBusy {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .buttonStyle(SoftRaisedPillStyle(height: pillHeight))
                    .disabled(isDisabled || store.isLoading || (store.purchasing != nil && !isBusy))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let err = store.lastError {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Pill Component
    @ViewBuilder
    private func walletBoostPill(icon: String, title: String, cost: Int, owned: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill").imageScale(.small)
                    Text("\(cost)").font(.caption2).monospacedDigit()
                }
                .opacity(0.9)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )

            // Count badge (top-right)
            if owned > 0 {
                Text("\(owned)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThickMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .shadow(radius: 2, y: 1)
                    .offset(x: 6, y: -6)
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct WalletPanelView_Previews: PreviewProvider {
    static var previews: some View {
        WalletPanelView(
            showCoinOverlay: .constant(false),
            pendingRewardCoins: .constant(0)
        )
        .environmentObject(LevelsService())
        .environmentObject(BoostsService())
        .environmentObject(GameState())
        .environmentObject(IAPManager())
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
