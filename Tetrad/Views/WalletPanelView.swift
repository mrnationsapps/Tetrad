import SwiftUI

struct WalletPanelView: View {
    @EnvironmentObject private var levels: LevelsService
    @EnvironmentObject private var boosts: BoostsService
    @EnvironmentObject private var game: GameState
    let dismiss: () -> Void

    @State private var showInsufficientCoins = false

    var body: some View {
        // Pending rewards (read-only notice)
        let unclaimed = Achievement.unclaimed(using: game)
        let pendingTotal = unclaimed.reduce(0) { $0 + $1.rewardCoins }

        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Wallet", systemImage: "creditcard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                    Text("\(levels.coins)").font(.headline).monospacedDigit()
                }
                .softRaisedCapsule()
            }

            // 🔔 Read-only notice (no CTA) when there are unclaimed rewards
            if pendingTotal > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .imageScale(.medium)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rewards Available")
                            .font(.subheadline).bold()
                        Text("Visit Achievements to collect.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.yellow.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.yellow.opacity(0.25), lineWidth: 1)
                        )
                )
            }

            // Buy Boosts
            VStack(alignment: .leading, spacing: 8) {
                Text("Buy Boosts").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    walletBoostPill(icon: "wand.and.stars", title: "Reveal ×1",  cost: 5)  { buyReveal(cost: 5,  count: 1) }
                    walletBoostPill(icon: "wand.and.stars", title: "Reveal ×3",  cost: 12) { buyReveal(cost: 12, count: 3) }
                    walletBoostPill(icon: "wand.and.stars", title: "Reveal ×10", cost: 35) { buyReveal(cost: 35, count: 10) }
                }
            }

            // Get Coins (IAP stubs)
            VStack(alignment: .leading, spacing: 8) {
                Text("Get Coins").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    walletIAPPill(amount: 100,  price: "$0.99") { addCoins(100) }
                    walletIAPPill(amount: 300,  price: "$2.99") { addCoins(300) }
                    walletIAPPill(amount: 1200, price: "$7.99") { addCoins(1200) }
                }
            }
        }
        .alert("Not enough coins", isPresented: $showInsufficientCoins) {
            Button("OK", role: .cancel) { }
        } message: { Text("You don't have enough coins for that purchase.") }
    }

    // MARK: - Actions

    private func buyReveal(cost: Int, count: Int) {
        if levels.coins >= cost {
            levels.addCoins(-cost)
            boosts.grant(count: count)
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            dismiss()
        } else {
            showInsufficientCoins = true
        }
    }

    private func addCoins(_ n: Int) {
        levels.addCoins(n)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        dismiss()
    }

    // MARK: - Tiny pills

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
            .foregroundStyle(.primary)
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
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
            .foregroundStyle(.primary)
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
