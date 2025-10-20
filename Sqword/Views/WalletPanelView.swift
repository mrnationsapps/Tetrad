//
//  WalletPanelView.swift
//  Sqword
//
//  Buy Boosts (Reveal 1/3/10 for 5/12/35 coins)
//  Get Coins via IAP (coins_50 / coins_200) — left-aligned, fixed pill width (90×48)
//

import SwiftUI

struct WalletPanelView: View {
    @EnvironmentObject private var levels: LevelsService
    @EnvironmentObject private var boosts: BoostsService
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var store: IAPManager   // ← IAP manager

    @State private var showToast = false
    @State private var toastText = ""

    // Back-compat with call sites like: WalletPanelView(dismiss: dismiss)
    var dismiss: (() -> Void)? = nil

    // Optional external control (e.g., to ghost while another panel is active)
    var isDisabled: Bool = false

    @State private var showInsufficientCoins = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            // BUY BOOSTS (coin → boost conversion)
            buyBoostsSection

            // GET COINS (StoreKit wired)
            getCoinsSection(isDisabled: isDisabled)
        }
        .padding(.vertical, 4)
        .alert("Not enough coins", isPresented: $showInsufficientCoins) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You don’t have enough coins for that boost.")
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

    // MARK: - Buy Boosts (Reveal)
    private var buyBoostsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Buy Boosts")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                walletBoostPill(icon: "wand.and.stars", title: "Reveal ×1",  cost: 5)  { buyReveal(cost: 5,  count: 1) }
                walletBoostPill(icon: "wand.and.stars", title: "Reveal ×3",  cost: 12) { buyReveal(cost: 12, count: 3) }
                walletBoostPill(icon: "wand.and.stars", title: "Reveal ×10", cost: 35) { buyReveal(cost: 35, count: 10) }
            }
        }
    }

    private func buyReveal(cost: Int, count: Int) {
        if levels.buyBoost(cost: cost, count: count, boosts: boosts, haptics: true) {
            // Safety: if BoostsService → GameState totals callback isn’t wired, increment here.
            if boosts.onBoostPurchased == nil {
                game.noteBoostPurchased(count: count)
            }
            dismiss?()
        } else {
            showInsufficientCoins = true
        }
    }

    // MARK: - Get Coins (IAP: coins_50 / coins_200)
    @ViewBuilder
    private func getCoinsSection(isDisabled: Bool) -> some View {
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
                                // Toast feedback
                                toastText = "+\(amount) coins added"
                                showToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    showToast = false
                                }
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

                            // Spinner only on the active purchase
                            if isBusy {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .buttonStyle(SoftRaisedPillStyle(height: pillHeight))
                    // Disable other pill while one is busy; also disable during initial load or external disable
                    .disabled(isDisabled || store.isLoading || (store.purchasing != nil && !isBusy))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let err = store.lastError {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Pills & Layout Helpers
@ViewBuilder
private func walletBoostPill(icon: String, title: String, cost: Int, action: @escaping () -> Void) -> some View {
    Button(action: action) {
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
    }
    .buttonStyle(.plain)
}

// MARK: - Preview
#if DEBUG
struct WalletPanelView_Previews: PreviewProvider {
    static var previews: some View {
        WalletPanelView()
            .environmentObject(LevelsService())
            .environmentObject(BoostsService())
            .environmentObject(GameState())
            .environmentObject(IAPManager())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
