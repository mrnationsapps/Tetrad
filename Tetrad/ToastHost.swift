import SwiftUI

/// Overlay renderer. Mount once near the top of your screens.
struct ToastHost: View {
    @EnvironmentObject private var toast: ToastCenter

    enum Placement { case bottom, center, top }

    var placement: Placement = .bottom
    var background: Color = Color(.systemBackground)

    var body: some View {
        ZStack {
            if let item = toast.current {
                // Entire pill is tappable
                Button {
                    item.onTap?()
                    toast.current = nil
                } label: {
                    Text(item.text)
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(background)
                                .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(edgeInsetPadding)
                .transition(transition)
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: item.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
        .allowsHitTesting(toast.current != nil)
        .ignoresSafeArea()
    }

    // MARK: - Helpers
    private var frameAlignment: Alignment {
        switch placement {
        case .bottom: return .bottom
        case .center: return .center
        case .top:    return .top
        }
    }

    private var edgeInsetPadding: EdgeInsets {
        switch placement {
        case .bottom: return EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 0)
        case .center: return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        case .top:    return EdgeInsets(top: 14, leading: 0, bottom: 0, trailing: 0)
        }
    }

    private var transition: AnyTransition {
        switch placement {
        case .bottom: return .move(edge: .bottom).combined(with: .opacity)
        case .top:    return .move(edge: .top).combined(with: .opacity)
        case .center: return .scale.combined(with: .opacity)
        }
    }
}
