//
//  FooterPanels.swift
//  Sqword
//
//  Created by kevin nations on 10/5/25.
//
import SwiftUI
import Lottie


/// Reusable host: attaches Boosts/Wallet slide-up panels + the Footer to any screen.
public struct FooterPanelsModifier<BoostsContent: View, WalletContent: View>: ViewModifier {
    @EnvironmentObject private var levels: LevelsService
    @EnvironmentObject private var game: GameState

    // Footer inputs
    let coins: Int?
    let boostsAvailable: Int?
    let isInteractable: Bool
    let isGameBoard: Bool

    // Panel builders (provide content; call `dismiss()` to close)
    let boostsPanel: (_ dismiss: @escaping () -> Void) -> BoostsContent
    let walletPanel: (_ dismiss: @escaping () -> Void) -> WalletContent
    
    let disabledStyle: FooterDisabledStyle

    // Internal presentation state
    @State private var showBoosts = false
    @State private var showWallet = false

    // NEW: once user opens Wallet this session, stop pulsing
    @State private var walletPulseDismissed = false

    // Coin chest animation state (top-level)
    @State private var showCoinOverlay = false
    @State private var pendingRewardCoins = 0

    // Panel look
    var panelHeight: CGFloat = 320
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    // Lottie Helpers
    @AppStorage("helper.wallet.seen") private var walletHelperSeen: Bool = false
    @AppStorage("helper.wallet2.seen") private var wallet2HelperSeen: Bool = false
    @AppStorage("helper.tapWallet.seen") private var tapWalletHelperSeen: Bool = false
    @State private var showWalletHelper = false
    @State private var walletButtonFrame: CGRect = .zero
    @State private var showWallet2Helper = false
    @State private var showTapWalletHelper = false
    
    
    // Lottie Helpers
    @ViewBuilder
    private var tapWalletHelperOverlay: some View {
        LottieView(
            name: "TapWallet_lottie",
            loop: .loop,
            speed: 1.0
        )
        .scaleEffect(0.8)
        .frame(width: 120, height: 120)
        .position(
            x: UIScreen.main.bounds.width * 0.25,  // Left side where wallet button is
            y: UIScreen.main.bounds.height - 400   // Bottom of screen
        )
        .allowsHitTesting(false)
        .zIndex(100)
    }
    
    @ViewBuilder
    private var walletHelperOverlay: some View {
        LottieView(
            name: "Wallet1_lottie",
            loop: .loop,
            speed: 1.0
        )
        .scaleEffect(0.6)
        .frame(width: 120, height: 120)
        .position(
            x: UIScreen.main.bounds.width * (isPad ? 0.49 : 0.49),  // 25% from left (wallet button area)
            y: UIScreen.main.bounds.height - (isPad ? 230 : 290)    // 100 points from bottom
        )
        .allowsHitTesting(false)
        .zIndex(100)
    }
    
    @ViewBuilder
    private var wallet2HelperOverlay: some View {
        LottieView(
            name: "Wallet2_lottie",
            loop: .loop,
            speed: 1.0
        )
        .scaleEffect(0.5)
        .frame(width: 120, height: 120)
        .position(
            x: UIScreen.main.bounds.width / (isPad ? 2 : 2),
            y: UIScreen.main.bounds.height / (isPad ? 2 : 3)
        )
        .allowsHitTesting(false)
        .zIndex(150)  // Above wallet panel
    }

    // Add explicit initializer
    init(
        coins: Int?,
        boostsAvailable: Int?,
        isInteractable: Bool,
        isGameBoard: Bool,
        boostsPanel: @escaping (_ dismiss: @escaping () -> Void) -> BoostsContent,
        walletPanel: @escaping (_ dismiss: @escaping () -> Void) -> WalletContent,
        disabledStyle: FooterDisabledStyle,
        panelHeight: CGFloat
    ) {
        self.coins = coins
        self.boostsAvailable = boostsAvailable
        self.isInteractable = isInteractable
        self.isGameBoard = isGameBoard
        self.boostsPanel = boostsPanel
        self.walletPanel = walletPanel
        self.disabledStyle = disabledStyle
        self.panelHeight = panelHeight
    }
    
    public func body(content: Content) -> some View {
        let hasUnclaimed = !Achievement.unclaimed(using: game).isEmpty
        let shouldPulseWallet = hasUnclaimed && !walletPulseDismissed && levels.hasUnlockedNonTutorial

        return ZStack {
            content
                // BOOSTS slide-up (with scrim)
                .overlay {
                    if showBoosts {
                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.black.opacity(0.01)) // must be non-clear to catch taps
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

            // WALLET slide-up (with scrim) - always use WalletPanelView with coin overlay
            .overlay {
                if showWallet {
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.black.opacity(0.01))
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showWallet2Helper = false
                                wallet2HelperSeen = true
                                withAnimation(.spring()) { showWallet = false }
                            }

                        VStack(spacing: 0) {
                            Capsule().frame(width: 44, height: 5).opacity(0.25).padding(.top, 8)

                            // Always use WalletPanelView with coin overlay bindings
                            WalletPanelView(
                                dismiss: {
                                    showWallet2Helper = false
                                    wallet2HelperSeen = true
                                    withAnimation(.spring()) { showWallet = false }
                                },
                                showCoinOverlay: $showCoinOverlay,
                                pendingRewardCoins: $pendingRewardCoins
                            )
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showWallet2Helper = false
                                wallet2HelperSeen = true
                            }
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
                    .onAppear {
                        if !wallet2HelperSeen {
                            showWallet2Helper = true
                        }
                    }
                }
            }

                // 🎁 Coin chest animation (top-level, full screen)
                .overlay {
                    if showCoinOverlay {
                        ZStack {
                            Color.black.opacity(0.25)
                                .ignoresSafeArea()
                                .transition(.opacity)
                            
                            CoinRewardOverlay(
                                isPresented: $showCoinOverlay,
                                amount: pendingRewardCoins
                            ) {
                                pendingRewardCoins = 0
                            }
                        }
                        .zIndex(250)
                        .transition(.opacity)
                    }
                }

                // Footer bar (drives the toggles)
                .overlay(alignment: .bottom) {
                    Footer(
                        coins: coins,
                        boostsAvailable: boostsAvailable,
                        isWalletActive: $showWallet,
                        isBoostsActive: $showBoosts,
                        isInteractable: isInteractable,
                        disabledStyle: disabledStyle,
                        isWalletEnabled: levels.hasUnlockedNonTutorial,
                        onTapWallet: {
                            showWalletHelper = false
                            walletHelperSeen = true
                            showTapWalletHelper = false
                            tapWalletHelperSeen = true
                            // Stop pulsing as soon as the player opens Wallet
                            if !showWallet { walletPulseDismissed = true }

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
                        },
                        walletPulse: shouldPulseWallet
                    )
                    .zIndex(10)
                }

                // When all rewards are collected, re-arm pulse for when new ones appear later
                .onChange(of: hasUnclaimed) { _, nowHasUnclaimed in
                    if !nowHasUnclaimed {
                        walletPulseDismissed = false
                    }
                }
            
            // When all rewards are collected, re-arm pulse for when new ones appear later
            .onChange(of: hasUnclaimed) { _, nowHasUnclaimed in
                if !nowHasUnclaimed {
                    walletPulseDismissed = false
                }
            }

            // Show tapWallet helper when wallet starts pulsing and on game board
            .onChange(of: shouldPulseWallet) { _, isPulsing in
                print("🔔 shouldPulseWallet changed: \(isPulsing), isGameBoard: \(isGameBoard), helperSeen: \(tapWalletHelperSeen)")
                if isPulsing && !tapWalletHelperSeen && isGameBoard {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("🎯 Showing tapWallet helper!")
                        showTapWalletHelper = true
                    }
                }
            }
            
                .onAppear {
                    // Show wallet helper on first appearance if not seen
                    if !walletHelperSeen {
                        showWalletHelper = true
                    }
                }
            
            // Wallet helper overlay (at ZStack level, won't affect layout)
//            if showWalletHelper && !walletHelperSeen {
//                walletHelperOverlay
//            }
            
            // Wallet2 helper overlay (shows when wallet panel is open)
//            if showWallet2Helper && !wallet2HelperSeen {
//                wallet2HelperOverlay
//            }
            
            // TapWallet helper overlay (shows when wallet is pulsing)
            if showTapWalletHelper && !tapWalletHelperSeen {
                tapWalletHelperOverlay
            }
        }
    }
}




public extension View {
    /// Attach a reusable Footer + slide-up panels to any screen.
    func withFooterPanels<BoostsContent: View, WalletContent: View>(
        coins: Int? = nil,
        boostsAvailable: Int? = nil,
        isInteractable: Bool = true,
        isGameBoard: Bool = false,
        disabledStyle: FooterDisabledStyle = .standard,
        panelHeight: CGFloat = 400,
        @ViewBuilder boostsPanel: @escaping (_ dismiss: @escaping () -> Void) -> BoostsContent,
        @ViewBuilder walletPanel: @escaping (_ dismiss: @escaping () -> Void) -> WalletContent
    ) -> some View {
        self.modifier(
            FooterPanelsModifier(
                coins: coins,
                boostsAvailable: boostsAvailable,
                isInteractable: isInteractable,
                isGameBoard: isGameBoard,  
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
