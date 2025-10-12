//  RewardOverlay.swift
//  Reusable reward overlay (e.g., for Achievement payouts)

import SwiftUI

public struct RewardOverlay: View {
    // MARK: - Public API
    public var title: String            // e.g. "Boom! Level Complete!" or "Achievement Reward"
    public var subtitle: String?        // optional line under title
    public var amount: Int              // coin amount to animate to
    public var showAura: Bool = true    // show ParticleAura behind the panel
    public var tapOutsideToDismiss: Bool = true

    public var primaryTitle: String = "Collect"
    public var primaryAction: () -> Void

    public var secondaryTitle: String? = nil
    public var secondaryAction: (() -> Void)? = nil

    public var onDismiss: (() -> Void)? = nil  // called after any dismissal

    // MARK: - Internal state
    @State private var counted: Double = 0
    @Environment(\.dismiss) private var dismissEnv   // if used modally

    public init(
        title: String = "Reward Unlocked!",
        subtitle: String? = nil,
        amount: Int,
        showAura: Bool = true,
        tapOutsideToDismiss: Bool = true,
        primaryTitle: String = "Collect",
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.showAura = showAura
        self.tapOutsideToDismiss = tapOutsideToDismiss
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // Dim background (dismiss on tap if desired)
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    guard tapOutsideToDismiss else { return }
                    dismissAll()
                }

            // Optional aura behind panel
            if showAura {
                ParticleAura()
                    .allowsHitTesting(false)
                    .opacity(0.9)
                    .transition(.opacity)
            }

            // Panel
            VStack(spacing: 14) {
                Text(title)
                    .font(.title).bold()
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Reward row with counting number
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .imageScale(.large)
                    Text("Reward:")
                        .font(.headline)
                    CountUpLabel(value: counted)
                        .foregroundStyle(.primary)
                    Text("coins")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
                .onAppear {
                    counted = 0
                    withAnimation(.easeOut(duration: 1.0)) {
                        counted = Double(amount)
                    }
#if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                }

                HStack(spacing: 10) {
                    if let secondaryTitle, let secondaryAction {
                        Button(secondaryTitle) {
                            secondaryAction()
                            dismissAll()
                        }
                        .buttonStyle(SoftRaisedPillStyle(height: 48))
                    }

                    Button(primaryTitle) {
                        primaryAction()
                        dismissAll()
                    }
                    .buttonStyle(SoftRaisedPillStyle(height: 48))
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .transition(.scale.combined(with: .opacity))
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func dismissAll() {
        onDismiss?()
        // If you're presenting this as part of a view state (e.g., if showRewardOverlay { ... }),
        // just flip that state in the caller inside onDismiss. If presented modally, this helps:
        dismissEnv()
    }
}

// MARK: - Count-up label
fileprivate struct CountUpLabel: View {
    var value: Double
    var body: some View {
        Text("\(Int(value.rounded()))")
            .font(.headline.monospacedDigit())
    }
}
