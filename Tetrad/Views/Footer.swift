import SwiftUI

// MARK: - Footer

public struct Footer: View {
    // Read-only display inputs (optional badges)
    public var coins: Int? = nil
    public var boostsAvailable: Int? = nil

    // Visual "selected" states (parent controls these)
    @Binding public var isWalletActive: Bool
    @Binding public var isBoostsActive: Bool

    // Interactivity gate (e.g., disable during banner/win-sheet/tutorial lock)
    public var isInteractable: Bool = true

    // Actions (parent decides what to present)
    public var onTapWallet: () -> Void
    public var onTapBoosts: () -> Void

    // Styling
    public var barBackground: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial)
    public var pillHeight: CGFloat = 44
    public var horizontalPadding: CGFloat = 16
    public var verticalPadding: CGFloat = 10

    public init(
        coins: Int? = nil,
        boostsAvailable: Int? = nil,
        isWalletActive: Binding<Bool>,
        isBoostsActive: Binding<Bool>,
        isInteractable: Bool = true,
        onTapWallet: @escaping () -> Void,
        onTapBoosts: @escaping () -> Void,
        barBackground: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial),
        pillHeight: CGFloat = 44,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 10
    ) {
        self.coins = coins
        self.boostsAvailable = boostsAvailable
        self._isWalletActive = isWalletActive
        self._isBoostsActive = isBoostsActive
        self.isInteractable = isInteractable
        self.onTapWallet = onTapWallet
        self.onTapBoosts = onTapBoosts
        self.barBackground = barBackground
        self.pillHeight = pillHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    public var body: some View {
        HStack(spacing: 12) {
            // WALLET
            Button(action: onTapWallet) {
                LabeledPill(
                    title: "Wallet",
                    systemImage: "creditcard",
                    badgeCount: coins
                )
                .accessibilityLabel(Text("Open Wallet"))
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
        .background(
            Rectangle()
                .fill(barBackground)
                .ignoresSafeArea(edges: .bottom)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.10), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .top)
                )
        )
        .allowsHitTesting(isInteractable)
        .opacity(isInteractable ? 1 : 0.6)
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


