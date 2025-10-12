import SwiftUI

// MARK: - Footer

// FILE LEVEL STUFFS
// Add at file scope
public enum FooterDisabledStyle {
    case standard     // existing look
    case ghosted      // extra-dim for tutorial

    var opacity: Double { self == .standard ? 0.6  : 0.24 }
    var grayscale: Double { self == .standard ? 0.0 : 0.9 }
    var saturation: Double { self == .standard ? 1.0 : 0.55 }
}

public struct Footer: View {
    @EnvironmentObject private var levels: LevelsService
    private var coinDisplay: Int { coins ?? levels.coins }

    public var coins: Int? = nil
    public var boostsAvailable: Int? = nil
    public var disabledStyle: FooterDisabledStyle = .standard

    @Binding public var isWalletActive: Bool
    @Binding public var isBoostsActive: Bool

    public var isInteractable: Bool = true
    public var isWalletEnabled: Bool = true

    public var onTapWallet: () -> Void
    public var onTapBoosts: () -> Void

    public var barBackground: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial)
    public var pillHeight: CGFloat = 44
    public var horizontalPadding: CGFloat = 16
    public var verticalPadding: CGFloat = 10
    public var walletPulse: Bool = false

    // NEW: local animation driver so we can *stop* repeatForever cleanly
    @State private var pulsePhase: CGFloat = 0   // 0 → 1
    private let pulseAmplitude: CGFloat = 0.20   // bump size (8%)

    public init(
        coins: Int? = nil,
        boostsAvailable: Int? = nil,
        isWalletActive: Binding<Bool>,
        isBoostsActive: Binding<Bool>,
        isInteractable: Bool = true,
        disabledStyle: FooterDisabledStyle = .standard,
        isWalletEnabled: Bool = true,
        onTapWallet: @escaping () -> Void,
        onTapBoosts: @escaping () -> Void,
        barBackground: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial),
        pillHeight: CGFloat = 44,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 10,
        walletPulse: Bool = false
    ) {
        self.coins = coins
        self.boostsAvailable = boostsAvailable
        self._isWalletActive = isWalletActive
        self._isBoostsActive = isBoostsActive
        self.isInteractable = isInteractable
        self.disabledStyle = disabledStyle
        self.isWalletEnabled = isWalletEnabled
        self.onTapWallet = onTapWallet
        self.onTapBoosts = onTapBoosts
        self.barBackground = barBackground
        self.pillHeight = pillHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.walletPulse = walletPulse
    }

    public var body: some View {
        let isPulsing = walletPulse && !isWalletActive

        HStack(spacing: 12) {
            // WALLET
            ZStack(alignment: .topTrailing) {
                Button(action: onTapWallet) {
                    LabeledPill(
                        title: "Wallet",
                        systemImage: "creditcard",
                        badgeCount: nil
                    )
                    .accessibilityLabel(Text("Open Wallet"))
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(key: WalletTargetKey.self,
                                                   value: g.frame(in: .global).center)
                        }
                    )
                }
                .buttonStyle(FooterPillButtonStyle(height: pillHeight))
                .background(
                    Capsule().fill(
                        isWalletActive
                        ? Color.accentColor.opacity(0.18)
                        : Color(.secondarySystemBackground)
                    )
                )
                .overlay(
                    Capsule().stroke(
                        isWalletActive ? Color.accentColor : Color.primary.opacity(0.12),
                        lineWidth: isWalletActive ? 1.25 : 1
                    )
                )
                // 👇 Pulse driven by local phase (cleanly stops when condition flips)
                .scaleEffect(1.0 + pulseAmplitude * pulsePhase)
                .onAppear {
                    if isPulsing {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            pulsePhase = 1
                        }
                    } else {
                        pulsePhase = 0
                    }
                }
                .onChange(of: isPulsing) { _, now in
                    if now {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            pulsePhase = 1
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) {
                            pulsePhase = 0
                        }
                    }
                }

                .disabled(!isInteractable || !isWalletEnabled)
                .opacity(isWalletEnabled ? 1.0 : 0.5)
                .grayscale(isWalletEnabled ? 0 : 0.25)

                // Always-on coin badge
                CoinBadge(coins: coinDisplay)
                    .offset(x: 9, y: -7)
                    .allowsHitTesting(false)
            }

            // BOOSTS
            Button(action: onTapBoosts) {
                LabeledPill(
                    title: "Boosts",
                    systemImage: "sparkles",
                    badgeCount: boostsAvailable
                )
                .accessibilityLabel(Text("Open Boosts"))
            }
            .buttonStyle(FooterPillButtonStyle(height: pillHeight))
            .background(
                Capsule().fill(
                    isBoostsActive
                    ? Color.accentColor.opacity(0.18)
                    : Color(.secondarySystemBackground)
                )
            )
            .overlay(
                Capsule().stroke(
                    isBoostsActive ? Color.accentColor : Color.primary.opacity(0.12),
                    lineWidth: isBoostsActive ? 1.25 : 1
                )
            )
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .allowsHitTesting(isInteractable)
        .opacity(isInteractable ? 1 : disabledStyle.opacity)
        .grayscale(isInteractable ? 0 : disabledStyle.grayscale)
        .saturation(isInteractable ? 1 : disabledStyle.saturation)
    }
}





// Small, legible badge used on the Wallet pill
private struct CoinBadge: View {
    let coins: Int
    private var text: String {
        coins > 999 ? "999+" : "\(coins)"
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded)) // bigger than 11
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color(red: 0.95, green: 0.23, blue: 0.24)) // rich red
            )
            .overlay(
                Capsule().stroke(.white.opacity(0.75), lineWidth: 0.5) // subtle ring
            )
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .minimumScaleFactor(0.8)
    }
}





// MARK: - Labeled pill with optional badge

fileprivate struct LabeledPill: View {
    let title: String
    let systemImage: String
    let badgeCount: Int?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)

            if let n = badgeCount, n > 0 {
                PillBadge(count: n)
                    .offset(x: 8, y: -8)
            }
        }
    }
}

// MARK: - Tiny badge

fileprivate struct PillBadge: View {
    let count: Int
    var body: some View {
        Text("\(min(count, 999))")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.red))
            .foregroundStyle(.white)
            .accessibilityHidden(true)
    }
}

// MARK: - Soft raised pill button style

fileprivate struct FooterPillButtonStyle: ButtonStyle {
    let height: CGFloat

    init(height: CGFloat = 44) {
        self.height = height
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(height: height)
            .padding(.vertical, 2)
            .padding(.horizontal, 2)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.10 : 0.18),
                    radius: configuration.isPressed ? 4 : 10,
                    x: 0, y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

// MARK: - Wallet target preference
struct WalletTargetKey: PreferenceKey {
    static var defaultValue: CGPoint? = nil
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}
private extension CGRect { var center: CGPoint { CGPoint(x: midX, y: midY) } }


