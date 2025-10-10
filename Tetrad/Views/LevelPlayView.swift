import SwiftUI
import UIKit

struct LevelPlayView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var levels: LevelsService
    @EnvironmentObject var boosts: BoostsService

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
    @State private var boostTest: Int = 0   // TEMP: remove when wired to real boosts store
    @State private var showInsufficientCoins = false
    @State private var isGenerating = false
    @State private var walletTargetGlobal: CGPoint? = nil
    @State private var rewardCount: Double = 0
    @State private var coinFly = false


    // MARK: - Main Body
    var body: some View {
        ZStack {
            boardLayer
                .modifier(FreezeAnimations(active: showWorldBanner)) // <- board never shifts

                .overlay(alignment: .center) { auraOverlay }   // UNDER banner
                .overlay(alignment: .center) { bannerOverlay } // OVER aura
        }
        // 1) particle aura
        //.overlay(auraOverlay, alignment: .center)

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

        .overlay(generatingOverlay)

        // 3) win overlay (stays)
        .overlay(winOverlay)
        
        .alert("Not enough coins", isPresented: $showInsufficientCoins) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You don't have enough coins for that purchase.")
        }
        
        .onPreferenceChange(WalletTargetKey.self) { walletTargetGlobal = $0 }
    }
    
    @ViewBuilder
    private var generatingOverlay: some View {
        if isGenerating {
            ZStack {
                Color.black.opacity(0.18).ignoresSafeArea()

                HStack(spacing: 10) {
                    ProgressView()
                    Text("Generating Puzzle…")
                        .font(.headline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
            }
            .transition(.opacity)
            .zIndex(100)
        }
    }

    private var effectiveBoostsRemaining: Int {
        // Use your real counter — pick the one that compiles:
        // return game.availableBoostsCount
        // return game.boostsRemaining
        return boosts.remaining
    }

    // Gate for the Reveal button
    private var canUseBoost: Bool {
        effectiveBoostsRemaining > 0 && !showWin && !showWorldBanner
    }

    // Call when a boost is successfully consumed
    private func onBoostConsumed() {
        if boostTest > 0 {
            boostTest -= 1
        } else {
            // If you have a real store, uncomment ONE of these:
            // _ = boosts.useOne()
            // _ = game.boosts.useOne()
        }
    }

    // Tile UI used in the panel
    @ViewBuilder
    private func boostTile(icon: String, title: String, material: Material) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(material)
                    .frame(width: 88, height: 88)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    
    // MARK: - Layers (kept small to help the type-checker)

    @ViewBuilder private var boardLayer: some View {
        ContentView(
            skipDailyBootstrap: true, enableDailyWinUI: false,
            showHeader: false    // ← hides the "TETRAD" title inside Level Play

        )
    }

    @ViewBuilder
    private var bannerOverlay: some View {
        if showWorldBanner, let word = game.worldWord {
            WorldWordBanner(
                word: word.uppercased(),
                gradient: worldGradient(for: world)
            )
            .fixedSize() // don’t consume layout
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { bannerSize = g.size }
                        .onChange(of: g.size) { _, s in bannerSize = s }
                }
            )
            .transition(.opacity)
            .allowsHitTesting(false)
            .zIndex(10)
        }
    }

    @ViewBuilder
    private var auraOverlay: some View {
        if showWorldBanner {
            // Fallback size so you see particles even before bannerSize arrives
            let w = (bannerSize == .zero ? 260 : bannerSize.width)  + 100
            let h = (bannerSize == .zero ?  90 : bannerSize.height) + 100

            ParticleAura()
                .frame(width: w, height: h)
                .opacity(0.9)
                .allowsHitTesting(false)
                .zIndex(9) // under the banner
                // simple fade; doesn’t affect layout
                .transition(.opacity)
        }
    }

    @ToolbarContentBuilder private var levelToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { dismiss() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left").imageScale(.medium)
                    Text("Back")
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(SoftRaisedPillStyle(height: 36))
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Text("\(world.name) | L\(levels.levelIndex(for: world) + 1)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(1.5)
        }

//        ToolbarItem(placement: .navigationBarTrailing) {
//            HStack(spacing: 6) {
//                Image(systemName: "dollarsign.circle.fill").imageScale(.large)
//                Text("\(levels.coins)")
//                    .font(.headline)
//                    .monospacedDigit()
//            }
//            .softRaisedCapsule()
//        }
    }

    @ViewBuilder private var winOverlay: some View {
        if showWin {
            ZStack {
                // Dim background
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)

                // 🎉 Confetti aura (behind the panel)
                ParticleAura()
                    .opacity(0.9)
                    .allowsHitTesting(false)

                // Panel
                VStack(spacing: 14) {
                    Text("Level Complete!")
                        .font(.title).bold()

                    let payout = levels.rewardCoins(for: game.moveCount, par: par)

                    // Reward row with counting number
                    HStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                        Text("Reward:").font(.headline)
                        CountUpLabel(value: rewardCount)
                            .foregroundStyle(.primary)
                        Text("coins")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                    .onAppear {
                        // Award once, then animate the number
                        awardCoinsOnce(payout.total)
                        rewardCount = 0
                        withAnimation(.easeOut(duration: 1.0)) {
                            rewardCount = Double(payout.total)
                        }
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    }

                    // Continue / Next
                    let hasNext = levels.hasNextLevel(for: world)

                    if hasNext {
                        HStack(spacing: 10) {
                            Button {
                                levels.advance(from: world)
                                showWin = false
                                rewardCount = 0
                                startNewSession()
                            } label: {
                                Text("Continue").font(.headline).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SoftRaisedPillStyle(height: 48))
                        }
                    } else {
                        Button {
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
            .onDisappear {
                rewardCount = 0
            }
        }
    }



    // MARK: - Helpers

    private struct FreezeAnimations: ViewModifier {
        let active: Bool
        func body(content: Content) -> some View {
            content.transaction { tx in
                if active { tx.animation = nil }   // disable implicit animations locally
            }
        }
    }

    private func buyRevealBoost(cost: Int, count: Int = 1) {
        if levels.coins >= cost {
            levels.addCoins(-cost)
            boosts.grant(count: count)
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } else {
            showInsufficientCoins = true
        }
    }

    private func simulateIAPPurchase(coins: Int) {
        levels.addCoins(coins)
    }
    
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

        // Reset view flags
        showWin = false
        didAwardCoins = false
        bannerWasShown = false
        showWorldBanner = false
        pendingWinDelay = false

        // Show loading, yield a frame so the overlay is visible, then build
        isGenerating = true
        Task {
            // Let SwiftUI render the overlay before the heavy work
            await Task.yield()

            // Start (your method is @MainActor; that's fine — we just yielded first)
            game.startLevelSession(seed: seed, dictionaryID: world.dictionaryID)

            isGenerating = false
        }
    }


    private func awardCoinsOnce(_ amount: Int) {
        guard !didAwardCoins else { return }
        didAwardCoins = true
        if amount > 0 {
            levels.addCoins(amount)
        }
        
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

//// MARK: - Particle Aura (radial burst, speed-governed wobble)
//private struct ParticleAura: View {
//    // Same public knobs so existing call sites keep working
//    var padding: CGFloat = 1            // distance from edges
//    var count: Int = 12                  // number of particles
//    var speed: Double = 1.25              // global time scale (lower = slower)
//    var size: CGFloat = 10.0              // core dot radius
//    var tailScale1: CGFloat = 0.73       // first trail size factor
//    var tailScale2: CGFloat = 0.50       // second trail size factor
//    var tint: Color = .white
//    var blendNormal: Bool = true         // false → additive glow
//    var wiggle: CGFloat = 1.0            // radial wobble amplitude (px)
//    var radialJitter: CGFloat = 12       // angle jitter (degrees)
//    var speedJitter: Double = 1.80       // per-particle speed variance
//
//    @State private var params: [Param] = []
//
//    private struct Param {
//        let angle: Double        // base direction (radians)
//        let phase0: Double       // initial progress offset (0..1)
//        let speedMul: Double     // speed multiplier
//        let wobblePhase: Double  // wobble phase
//        let wobbleFreq: Double   // wobble frequency (Hz-ish)
//        let wobbleAmp: Double    // wobble amplitude (px)
//    }
//
//    private func makeParams(_ n: Int) -> [Param] {
//        (0..<n).map { i in
//            let baseAngle = Double(i) * (2 * .pi) / Double(max(1, n))
//            let jitterRad = Double(radialJitter) * (.pi / 180)
//            let jitter    = Double.random(in: -jitterRad...jitterRad)
//            return Param(
//                angle: baseAngle + jitter,
//                phase0: Double.random(in: 0..<1),
//                speedMul: Double.random(in: (1.0 - speedJitter)...(1.0 + speedJitter)),
//                wobblePhase: Double.random(in: 0..<(2 * .pi)),
//                wobbleFreq: Double.random(in: 0.8...1.4),
//                wobbleAmp: Double.random(in: 0.10...0.35) * Double(max(0, wiggle))
//            )
//        }
//    }
//
//    var body: some View {
//        GeometryReader { geo in
//            let w = geo.size.width, h = geo.size.height
//            let cx = w / 2, cy = h / 2
//            let maxR = max(0, min(w, h) / 2 - padding)
//            let edgeGuard = max(size * 1.5, 2)
//
//            TimelineView(.periodic(from: Date(), by: 1.0 / 60.0)) { tl in
//                let t = tl.date.timeIntervalSinceReferenceDate
//                let tScaled = t * max(0.0001, speed)   // one timebase that obeys `speed`
//
//                Canvas { ctx, _ in
//                    ctx.blendMode = blendNormal ? .normal : .plusLighter
//
//                    let ps = (params.count == count) ? params : makeParams(count)
//
//                    for i in 0..<ps.count {
//                        let p = ps[i]
//
//                        // Outward progress 0→1 (looping), eased for a soft bloom
//                        let prog  = ((tScaled * p.speedMul + p.phase0).truncatingRemainder(dividingBy: 1))
//                        let eased = 1 - pow(1 - prog, 1.6)
//
//                        // Radial wobble uses the SAME scaled timebase
//                        let wobble = sin(tScaled * p.wobbleFreq + p.wobblePhase) * p.wobbleAmp
//                        let r = max(0, min(maxR - edgeGuard, eased * maxR + wobble))
//
//                        let x = cx + CGFloat(cos(p.angle)) * CGFloat(r)
//                        let y = cy + CGFloat(sin(p.angle)) * CGFloat(r)
//
//                        // Core dot
//                        let coreR: CGFloat = size
//                        var core = Path(ellipseIn: CGRect(x: x - coreR, y: y - coreR, width: coreR * 2, height: coreR * 2))
//                        let alpha = (1 - eased) * 0.9     // fade as it travels out
//                        ctx.opacity = alpha
//                        ctx.fill(core, with: .color(tint))
//
//                        // Two trailing echoes marching toward center
//                        func trail(back: Double, scale: CGFloat, mult: Double) {
//                            let tProg = max(0, eased - back)
//                            let tr = max(0, min(maxR - edgeGuard, tProg * maxR))
//                            let tx = cx + CGFloat(cos(p.angle)) * CGFloat(tr)
//                            let ty = cy + CGFloat(sin(p.angle)) * CGFloat(tr)
//                            let sr = coreR * scale
//                            var tail = Path(ellipseIn: CGRect(x: tx - sr, y: ty - sr, width: sr * 2, height: sr * 2))
//                            ctx.opacity = alpha * mult
//                            ctx.fill(tail, with: .color(tint))
//                        }
//                        trail(back: 0.08, scale: tailScale1, mult: 0.45)
//                        trail(back: 0.16, scale: tailScale2, mult: 0.25)
//                    }
//                }
//            }
//        }
//        .onAppear { if params.count != count { params = makeParams(count) } }
//        .onChange(of: count) { _, n in params = makeParams(n) }
//        .allowsHitTesting(false)
//    }
//}




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

private struct CountUpLabel: View, Animatable {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View {
        Text("\(Int(value))")
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .monospacedDigit()
    }
}

