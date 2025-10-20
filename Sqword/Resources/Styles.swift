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

public struct SoftRaisedPillStyle: ButtonStyle {
    var height: CGFloat = 48
    var fill: Color = Color(.secondarySystemBackground)   // 👈 NEW: tint
    var foreground: Color = .primary                      // 👈 optional
    var stroke: Color = Color.white.opacity(0.22)         // 👈 optional

    public init(height: CGFloat = 48,
                fill: Color = Color(.secondarySystemBackground),
                foreground: Color = .primary,
                stroke: Color = Color.white.opacity(0.22)) {
        self.height = height
        self.fill = fill
        self.foreground = foreground
        self.stroke = stroke
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(fill)
                    .overlay(
                        Capsule().stroke(stroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(pressed ? 0.15 : 0.25),
                            radius: pressed ? 4 : 8, y: pressed ? 2 : 4)
            )
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}


extension View {
    /// Soft-raised pill. Use on the Boosts/Letters toggle or other pill actions.
    func softRaisedCapsule(pressed: Bool = false) -> some View {
        modifier(SoftRaisedCapsule(pressed: pressed))
    }
}

extension Color {
    static let beige     = Color(red: 0.96, green: 0.96, blue: 0.86) // #F5F5DC classic beige
    static let sand      = Color(red: 0.94, green: 0.89, blue: 0.78) // #F0E3C7
    static let cream     = Color(red: 1.00, green: 0.97, blue: 0.90) // #FFF7E6
    static let parchment = Color(red: 0.98, green: 0.93, blue: 0.83) // #FAEED4
    static let darkparchment = Color(red: 0.588, green: 0.558, blue: 0.498) // #968E7F
    static let warmCanvas = Color(red: 0.961, green: 0.941, blue: 0.902) // #F5F0E6
    static let softSand   = Color(red: 0.937, green: 0.906, blue: 0.855) // #EFE7DA
    static let creamMist  = Color(red: 0.969, green: 0.953, blue: 0.925) // #F7F3EC
    static let warmCanvasSat = Color(red: 0.965, green: 0.918, blue: 0.847) // #F6EAD8
    static let creamMistSat  = Color(red: 0.976, green: 0.941, blue: 0.886) // #F9F0E2

    static let softSandSat   = Color(red: 0.941, green: 0.882, blue: 0.788) // #F0E1C9
    static let softSandBright = Color(red: 1.000, green: 0.973, blue: 0.925) // #FFF8EC
    static let softgreen = Color(red: 0.514, green: 0.612, blue: 0.588) // #839C96
    static let softSage = Color(red: 0.686, green: 0.741, blue: 0.729) // #AFBDBA
    static let softYellow = Color(red: 0.961, green: 0.902, blue: 0.651) // #F5E6A6
    static let blazingYellow = Color(red: 1.000, green: 1.000, blue: 0.000) // #FFFF00















    










}
