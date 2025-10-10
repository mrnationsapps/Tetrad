//
//  FooterPanels.swift
//  Tetrad
//
//  Created by kevin nations on 10/5/25.
//
import SwiftUI

/// Reusable host: attaches Boosts/Wallet slide-up panels + the Footer to any screen.
public struct FooterPanelsModifier<BoostsContent: View, WalletContent: View>: ViewModifier {
    @EnvironmentObject private var levels: LevelsService
    // Footer inputs
    let coins: Int?
    let boostsAvailable: Int?
    let isInteractable: Bool

    // Panel builders (provide content; call `dismiss()` to close)
    let boostsPanel: (_ dismiss: @escaping () -> Void) -> BoostsContent
    let walletPanel: (_ dismiss: @escaping () -> Void) -> WalletContent
    
    let disabledStyle: FooterDisabledStyle

    // Internal presentation state
    @State private var showBoosts = false
    @State private var showWallet = false

    // Panel look
    var panelHeight: CGFloat = 320

    public func body(content: Content) -> some View {
        content
            // BOOSTS slide-up (with scrim)
            .overlay {
                if showBoosts {
                    ZStack(alignment: .bottom) {
                        // ⬇️ Make scrim tappable (not clear)
                        Rectangle()
                            .fill(Color.black.opacity(0.01))
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation(.spring()) { showBoosts = false } }

                        VStack(spacing: 0) {
                            Capsule().frame(width: 44, height: 5).opacity(0.25).padding(.top, 8)

                            boostsPanel { withAnimation(.spring()) { showBoosts = false } }
                                .padding(16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: panelHeight)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(50)
                }
            }

            // WALLET slide-up (with scrim) – same container for consistency
            .overlay {
                if showWallet {
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.black.opacity(0.01))
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation(.spring()) { showWallet = false } }

                        VStack(spacing: 0) {
                            Capsule().frame(width: 44, height: 5).opacity(0.25).padding(.top, 8)

                            walletPanel { withAnimation(.spring()) { showWallet = false } }
                                .padding(16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: panelHeight)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(50)
                }
            }

            // Footer bar (drives the toggles)
            .safeAreaInset(edge: .bottom) {
                Footer(
                    coins: coins,
                    boostsAvailable: boostsAvailable,
                    isWalletActive: $showWallet,
                    isBoostsActive: $showBoosts,
                    isInteractable: isInteractable,
                    disabledStyle: disabledStyle,
                    isWalletEnabled: levels.hasUnlockedNonTutorial,
                    onTapWallet: {
                        if showBoosts {
                            withAnimation(.spring()) { showBoosts = false }
                            withAnimation(.spring().delay(0.12)) { showWallet = true }
                        } else {
                            withAnimation(.spring()) { showWallet.toggle() }
                        }
                    },
                    onTapBoosts: {
                        if showWallet {
                            withAnimation(.spring()) { showWallet = false }
                            withAnimation(.spring().delay(0.12)) { showBoosts = true }
                        } else {
                            withAnimation(.spring()) { showBoosts.toggle() }
                        }
                    }
                )
                .zIndex(10)
            }
    }
}


public extension View {
    /// Attach a reusable Footer + slide-up panels to any screen.
    func withFooterPanels<BoostsContent: View, WalletContent: View>(
        coins: Int? = nil,
        boostsAvailable: Int? = nil,
        isInteractable: Bool = true,
        disabledStyle: FooterDisabledStyle = .standard,
        panelHeight: CGFloat = 320,
        @ViewBuilder boostsPanel: @escaping (_ dismiss: @escaping () -> Void) -> BoostsContent,
        @ViewBuilder walletPanel: @escaping (_ dismiss: @escaping () -> Void) -> WalletContent
    ) -> some View {
        self.modifier(
            FooterPanelsModifier(
                coins: coins,
                boostsAvailable: boostsAvailable,
                isInteractable: isInteractable,
                boostsPanel: boostsPanel,
                walletPanel: walletPanel,
                disabledStyle: disabledStyle,
                panelHeight: panelHeight

            )
        )
    }
}

// MARK: - Wallet Pills (shared UI for all screens)

public struct WalletBoostPill: View {
    let icon: String
    let title: String
    let cost: Int
    let action: () -> Void

    public var body: some View {
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
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground)) // solid card, no blurry material
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

public struct WalletIAPPill: View {
    let amount: Int
    let price: String
    let action: () -> Void

    public var body: some View {
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
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
