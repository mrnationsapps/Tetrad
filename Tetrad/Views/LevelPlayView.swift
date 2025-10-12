import SwiftUI
import UIKit

struct LevelPlayView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var levels: LevelsService
    @EnvironmentObject var boosts: BoostsService
    @EnvironmentObject var toast: ToastCenter

    let world: World

    @State private var didStart = false
    @State private var showWin = false
    @State private var didAwardCoins = false
    @State private var par: Int = 0
    @State private var navigateToAchievements = false


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
            Color.softSandSat.ignoresSafeArea()   // ← back layer

            boardLayer
                .modifier(FreezeAnimations(active: showWorldBanner)) // <- board never shifts

                .overlay(alignment: .center) { auraOverlay }   // UNDER banner
                .overlay(alignment: .center) { bannerOverlay } // OVER aura
            
            ToastHost()
                .environmentObject(ToastCenter.shared)
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

            let fireWinAndToast = {
                withAnimation(.spring()) { showWin = true }

                // 🔔 If any new achievements are now unlocked but unclaimed, show a toast
                let newlyUnclaimed = Achievement.unclaimed(using: game)
                if !newlyUnclaimed.isEmpty {
                    toast.showAchievementUnlock(count: newlyUnclaimed.count) {
                    }
                }

            }

            if showWorldBanner || pendingWinDelay {
                pendingWinDelay = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    pendingWinDelay = false
                    fireWinAndToast()
                }
            } else {
                fireWinAndToast()
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
            skipDailyBootstrap: true,
            enableDailyWinUI: false,
            showHeader: false
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

        ToolbarItem(placement: .navigationBarTrailing) {
            Text("\(world.name) | L\(levels.levelIndex(for: world) + 1)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(1.5)
        }

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
        Task { @MainActor in
            // Let SwiftUI render the overlay before the heavy work
            await Task.yield()

            // NEW: use the helper; pass UInt64 seed; optionally resume prior snapshot
            game.startLevelRun(
                seed: UInt64(seed),
                dictionaryID: world.dictionaryID,
                resumeIfAvailable: true
            )

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

        VStack(spacing: 8) {
            // Fixed heading
            Text("World Word Found!")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                .accessibilityHidden(true)

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
