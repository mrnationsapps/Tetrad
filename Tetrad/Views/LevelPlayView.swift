import SwiftUI
import UIKit

struct LevelPlayView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var levels: LevelsService

    let world: World

    @State private var didStart = false
    @State private var showWin = false
    @State private var didAwardCoins = false
    @State private var par: Int = 0

    // Banner state
    @State private var showWorldBanner = false
    @State private var bannerWasShown = false
    @State private var pendingWinDelay = false
    @State private var bannerSize: CGSize = .zero
    
    @State private var walletOpen = false
    @State private var boostsOpen = false



    // MARK: - Main Body
    var body: some View {
        ZStack {
            boardLayer
            bannerLayer
        }
        // 1) particle aura
        .overlay(auraOverlay, alignment: .center)

        // 2) your existing animations / toolbar / lifecycle
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showWorldBanner)
        .navigationBarBackButtonHidden(true)
        .toolbar { levelToolbar }

        .onAppear {
            guard !didStart else { return }
            didStart = true
            startNewSession()
        }

        // World word completed → show banner
        .onChange(of: game.worldWordJustCompleted) { _, justCompleted in
            guard justCompleted else { return }
            triggerWorldBanner()
        }

        // Solve handling (delay if banner also firing)
        .onChange(of: game.solved) { _, isSolved in
            guard isSolved && game.isLevelMode else { return }
            if showWorldBanner || pendingWinDelay {
                pendingWinDelay = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    pendingWinDelay = false
                    withAnimation(.spring()) { showWin = true }
                }
            } else {
                withAnimation(.spring()) { showWin = true }
            }
        }

        // 3) win overlay (stays)
        .overlay(winOverlay)

        // 4) BOOSTS slide-up panel (shim for now)
        .overlay(alignment: .bottom, content: {
            if boostsOpen {
                BoostsSlideUpShim(onClose: { boostsOpen = false })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(50) // above footer
            }
        })


        // 5) FOOTER — drives walletOpen/boostsOpen
        .safeAreaInset(edge: .bottom) {
            Footer(
                coins: nil,                   // <-- no coins in this scope yet
                boostsAvailable: nil,         // <-- no boosts count in this scope yet
                isWalletActive: $walletOpen,
                isBoostsActive: $boostsOpen,
                isInteractable: !showWin && !showWorldBanner,
                onTapWallet: { walletOpen.toggle() },
                onTapBoosts: { boostsOpen.toggle() }
            )
            .zIndex(10)
        }

    }


    private struct BoostsSlideUpShim: View {
        var onClose: () -> Void
        var body: some View {
            VStack(spacing: 12) {
                Capsule().frame(width: 44, height: 5).opacity(0.25).padding(.top, 8)
                Text("Boosts").font(.headline)
                Text("Temporary panel shim — replace with your real Boosts panel.")
                    .font(.footnote).multilineTextAlignment(.center).opacity(0.7)
                Button("Close", action: onClose).padding(.top, 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20, y: 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    
    // MARK: - Layers (kept small to help the type-checker)

    @ViewBuilder private var boardLayer: some View {
        ContentView(skipDailyBootstrap: true, enableDailyWinUI: false)
    }

    @ViewBuilder private var bannerLayer: some View {
        if showWorldBanner, let word = game.worldWord {
            WorldWordBanner(
                word: word.uppercased(),
                gradient: worldGradient(for: world)
            )
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { bannerSize = g.size }
                        .onChange(of: g.size) { _, newSize in
                            bannerSize = newSize
                        }
                }
            )
            .transition(
                .asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal:   .move(edge: .trailing).combined(with: .opacity)
                )
            )
            .zIndex(10)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder private var auraOverlay: some View {
        if showWorldBanner, bannerSize != .zero {
            let auraPadding: CGFloat = 50   // distance outside the pill
            ParticleAura(
                padding: 10,                 // small inset inside aura frame
                count: 18,
                speed: 0.45,
                size: 6.0,
                tint: worldParticleTint(for: world),
                blendNormal: true,
                wiggle: 10.0,
                radialJitter: 40,
                speedJitter: 0.30
            )
            .frame(
                width:  bannerSize.width  + auraPadding * 2,
                height: bannerSize.height + auraPadding * 2
            )
            .allowsHitTesting(false)
            .transition(.opacity)
            .zIndex(11)
        }
    }

    @ToolbarContentBuilder private var levelToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { dismiss() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").imageScale(.medium)
                }
            }
            .buttonStyle(SoftRaisedPillStyle(height: 36))
        }

        ToolbarItem(placement: .principal) {
            Text("\(world.name) | L\(levels.levelIndex(for: world) + 1)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(1.5)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                Text("\(levels.coins)")
                    .font(.headline)
                    .monospacedDigit()
            }
            .softRaisedCapsule()
        }
    }

    @ViewBuilder private var winOverlay: some View {
        if showWin {
            Color.black.opacity(0.25).ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 14) {
                Text("You got it!").font(.title).bold()

                let payout = levels.rewardCoins(for: game.moveCount, par: par)

                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                    if payout.bonus > 0 {
                        Text("+$\(payout.total)  (+$\(payout.bonus) bonus)").font(.headline)
                    } else {
                        Text("+$\(payout.total)").font(.headline)
                    }
                }
                .foregroundStyle(.secondary)

                let hasNext = levels.hasNextLevel(for: world)

                if hasNext {
                    HStack(spacing: 10) {
                        Button {
                            awardCoinsOnce(payout.total)
                            dismiss()
                        } label: {
                            Text("Quit").font(.headline).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SoftRaisedPillStyle(height: 48))

                        Button {
                            awardCoinsOnce(payout.total)
                            levels.advance(from: world)
                            showWin = false
                            startNewSession()
                        } label: {
                            Text("Continue").font(.headline).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SoftRaisedPillStyle(height: 48))
                    }
                } else {
                    Button {
                        awardCoinsOnce(payout.total)
                        dismiss()
                    } label: {
                        Text("Continue").font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftRaisedPillStyle(height: 48))
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private func worldIndexK() -> Int? {
        let rows = game.worldProtectedCoords.map(\.row)
        guard !rows.isEmpty else { return nil }
        let counts = Dictionary(grouping: rows, by: { $0 }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func startNewSession() {
        let idx  = levels.levelIndex(for: world)
        par      = levels.levelPar(for: world, levelIndex: idx)
        let seed = levels.seed(for: world, levelIndex: idx)

        game.startLevelSession(seed: seed, dictionaryID: world.dictionaryID)

        showWin = false
        didAwardCoins = false
        bannerWasShown = false
        showWorldBanner = false
        pendingWinDelay = false
    }

    private func awardCoinsOnce(_ amount: Int) {
        guard !didAwardCoins else { return }
        didAwardCoins = true
        levels.addCoins(amount)
    }

    /// Left → center (show), hold ~2s, right (hide)
    private func triggerWorldBanner() {
        guard !bannerWasShown else { return }
        bannerWasShown = true

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let word = game.worldWord {
            UIAccessibility.post(notification: .announcement, argument: "\(word) found")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                showWorldBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showWorldBanner = false
                }
            }
        }
    }

    // MARK: - Theming
    private func worldGradient(for world: World) -> LinearGradient {
        let name = world.name.lowercased()
        let colors: [Color]
        if name.contains("food") {
            colors = [Color(hue: 0.04, saturation: 0.85, brightness: 1.0),
                      Color(hue: 0.95, saturation: 0.65, brightness: 0.95)]
        } else if name.contains("nature") {
            colors = [Color(hue: 0.33, saturation: 0.75, brightness: 0.95),
                      Color(hue: 0.38, saturation: 0.80, brightness: 0.90)]
        } else if name.contains("retro") {
            colors = [Color(hue: 0.85, saturation: 0.75, brightness: 1.0),
                      Color(hue: 0.52, saturation: 0.80, brightness: 0.95)]
        } else if name.contains("travel") {
            colors = [Color(hue: 0.58, saturation: 0.75, brightness: 1.0),
                      Color(hue: 0.60, saturation: 0.55, brightness: 0.95)]
        } else if name.contains("animals") {
            colors = [Color(hue: 0.10, saturation: 0.65, brightness: 1.0),
                      Color(hue: 0.07, saturation: 0.75, brightness: 0.95)]
        } else {
            colors = [Color.accentColor, Color.accentColor.opacity(0.8)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func worldParticleTint(for world: World) -> Color {
        let n = world.name.lowercased()
        if n.contains("food")    { return .orange }
        if n.contains("nature")  { return .green }
        if n.contains("retro")   { return .pink }
        if n.contains("travel")  { return .cyan }
        if n.contains("animals") { return .yellow }
        return .white
    }
}

// MARK: - Particle Aura (unchanged from your file)
private struct ParticleAura: View {
    var padding: CGFloat = 10
    var count: Int = 12
    var speed: Double = 0.6
    var size: CGFloat = 2.2
    var tailScale1: CGFloat = 0.73
    var tailScale2: CGFloat = 0.50
    var tint: Color = .white
    var blendNormal: Bool = true
    var wiggle: CGFloat = 1.0
    var radialJitter: CGFloat = 12
    var speedJitter: Double = 0.25

    @State private var params: [Param] = []

    private struct Param {
        let phase0: Double, wobblePhase: Double, wobbleAmp: Double, wobbleFreq: Double
        let radiusOffset: CGFloat, speedMul: Double
    }

    private func makeParams(_ n: Int) -> [Param] {
        (0..<n).map { _ in
            Param(
                phase0: Double.random(in: 0..<(2 * .pi)),
                wobblePhase: Double.random(in: 0..<(2 * .pi)),
                wobbleAmp: Double.random(in: 0.10...0.35) * Double(max(0, wiggle)),
                wobbleFreq: Double.random(in: 0.8...1.4),
                radiusOffset: CGFloat.random(in: -radialJitter...radialJitter),
                speedMul: Double.random(in: (1.0 - speedJitter)...(1.0 + speedJitter))
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let rxInner = max(0, w / 2 - padding)
            let ryInner = max(0, h / 2 - padding)
            let edgeGuard = max(size * 1.5, 2)

            TimelineView(.periodic(from: Date(), by: 1.0 / 60.0)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate

                Canvas { ctx, sz in
                    ctx.blendMode = blendNormal ? .normal : .plusLighter

                    let ps = (params.count == count) ? params :
                        (0..<count).map { i in
                            Param(phase0: Double(i) * .pi * 2 / Double(max(1, count)),
                                  wobblePhase: Double(i) * 0.37,
                                  wobbleAmp: 0.18 * Double(max(0, wiggle)),
                                  wobbleFreq: 1.1,
                                  radiusOffset: 0,
                                  speedMul: 1.0)
                        }

                    let cx = sz.width  / 2
                    let cy = sz.height / 2

                    for i in 0..<count {
                        let p = ps[i]

                        let base   = t * speed * p.speedMul + Double(i) * .pi * 2 / Double(count) + p.phase0
                        let wobble = sin(t * p.wobbleFreq + p.wobblePhase) * p.wobbleAmp
                        let a = base + wobble

                        let rx = max(0, min(rxInner - edgeGuard, rxInner + p.radiusOffset))
                        let ry = max(0, min(ryInner - edgeGuard, ryInner + p.radiusOffset))

                        let x = cx + cos(a) * rx
                        let y = cy + sin(a) * ry

                        let r: CGFloat = size
                        var dot = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                        let flicker = 0.35 + 0.25 * (0.5 + 0.5 * sin(t * 1.2 + Double(i)))
                        ctx.opacity = flicker
                        ctx.fill(dot, with: .color(tint))

                        for k in 1...2 {
                            let trailA = a - Double(k) * 0.12
                            let tx = cx + cos(trailA) * rx
                            let ty = cy + sin(trailA) * ry
                            let sr: CGFloat = (k == 1) ? size * tailScale1 : size * tailScale2
                            var tail = Path(ellipseIn: CGRect(x: tx - sr, y: ty - sr, width: sr * 2, height: sr * 2))
                            ctx.opacity = flicker * (k == 1 ? 0.45 : 0.25)
                            ctx.fill(tail, with: .color(tint))
                        }
                    }
                }
            }
        }
        .onAppear { if params.count != count { params = makeParams(count) } }
        .onChange(of: count) { _, newCount in params = makeParams(newCount) }
        .allowsHitTesting(false)
    }
}

// MARK: - Banner View
private struct WorldWordBanner: View {
    let word: String
    let gradient: LinearGradient
    @State private var runSheen = false

    var body: some View {
        let label = Text(word)
            .font(.system(size: 80, weight: .heavy))
            .kerning(0.5)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

        label
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(gradient)
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .shadow(radius: 10, x: 0, y: 6)
            )
            .fixedSize(horizontal: true, vertical: true)
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let band = max(56, w * 0.35)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.0), .white.opacity(0.28), .white.opacity(0.0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: band, height: h + 8)
                        .rotationEffect(.degrees(24))
                        .offset(x: runSheen ? w + band : -band)
                        .allowsHitTesting(false)
                        .onAppear {
                            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                                runSheen = true
                            }
                        }
                }
                .clipShape(Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(word))
    }
}
