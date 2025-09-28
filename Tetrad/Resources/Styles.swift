import SwiftUI

// MARK: - Soft Raised (neumorphic) — Rounded Rectangle
struct SoftRaised: ViewModifier {
    var corner: CGFloat = 12
    var pressed: Bool = false
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let fillLight   = Color(red: 246/255, green: 249/255, blue: 252/255) // #F6F9FC
        let fillDark    = Color(red:  18/255, green:  21/255, blue:  27/255) // #12151B
        let borderLight = Color(red: 218/255, green: 223/255, blue: 230/255) // #DADFE6
        let borderDark  = Color(red:  37/255, green:  42/255, blue:  51/255) // #252A33

        let fill   = scheme == .dark ? fillDark   : fillLight
        let border = scheme == .dark ? borderDark : borderLight

        let shadowOpacity: CGFloat  = pressed ? 0.06 : 0.10   // Outer soft shadow (light)
        let shadowRadius: CGFloat   = pressed ? 4    : 8
        let shadowY: CGFloat        = pressed ? 0    : 2
        let highlightOpacity: CGFloat = pressed ? 0.15 : 0.35 // Inner top highlight

        return content
            .background(
                RoundedRectangle(cornerRadius: corner)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(border, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(shadowOpacity),
                            radius: shadowRadius, x: 0, y: shadowY)
                    .overlay(
                        // Inner top highlight (bevel)
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(Color.white.opacity(highlightOpacity), lineWidth: 1)
                            .mask(
                                LinearGradient(colors: [.white, .clear],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .blur(radius: 2)
                            .offset(y: -1)
                    )
            )
    }
}
extension View {
    /// Soft-raised beveled surface. Use on board cells, neutral tiles, small panels.
    func softRaised(corner: CGFloat = 12, pressed: Bool = false) -> some View {
        modifier(SoftRaised(corner: corner, pressed: pressed))
    }
}

// MARK: - Soft Raised — Capsule (pill buttons)
struct SoftRaisedCapsule: ViewModifier {
    var pressed: Bool = false
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let fillLight   = Color(red: 246/255, green: 249/255, blue: 252/255)
        let fillDark    = Color(red:  18/255, green:  21/255, blue:  27/255)
        let borderLight = Color(red: 218/255, green: 223/255, blue: 230/255)
        let borderDark  = Color(red:  37/255, green:  42/255, blue:  51/255)

        let fill   = scheme == .dark ? fillDark   : fillLight
        let border = scheme == .dark ? borderDark : borderLight

        let shadowOpacity: CGFloat  = pressed ? 0.06 : 0.10
        let shadowRadius: CGFloat   = pressed ? 4    : 8
        let shadowY: CGFloat        = pressed ? 0    : 2
        let highlightOpacity: CGFloat = pressed ? 0.15 : 0.35

        return content
            .background(
                Capsule()
                    .fill(fill)
                    .overlay(Capsule().stroke(border, lineWidth: 1))
                    .shadow(color: .black.opacity(shadowOpacity),
                            radius: shadowRadius, x: 0, y: shadowY)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(highlightOpacity), lineWidth: 1)
                            .mask(
                                LinearGradient(colors: [.white, .clear],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .blur(radius: 2)
                            .offset(y: -1)
                    )
            )
    }
}

struct SoftRaisedPillStyle: ButtonStyle {
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 20)
            .frame(height: height)
            .contentShape(Capsule())
            .softRaisedCapsule(pressed: configuration.isPressed) // 👈 uses your style
    }
}

extension View {
    /// Soft-raised pill. Use on the Boosts/Letters toggle or other pill actions.
    func softRaisedCapsule(pressed: Bool = false) -> some View {
        modifier(SoftRaisedCapsule(pressed: pressed))
    }
}
