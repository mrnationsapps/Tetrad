import SwiftUI
import UIKit

struct LevelPlayView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var levels: LevelsService
    @EnvironmentObject var boosts: BoostsService
    @EnvironmentObject private var music: MusicCenter

    let world: World

    @State private var didStart = false
    @State private var showWin = false
    @State private var didAwardCoins = false
    @State private var par: Int = 0
    @State private var navigateToAchievements = false

    // 🎬 Coin reward flow
    @State private var showCoinOverlay = false
    @State private var pendingRewardCoins = 0
    @State private var showFinishLottie = false
    @State private var finishStopIndex = 0
    
    // Banner state
    @State private var showWorldBanner = false
    @State private var bannerWasShown = false
    @State private var pendingWinDelay = false
    @State private var bannerSize: CGSize = .zero
    @State private var boostTest: Int = 0   // TEMP: remove when wired to real boosts store
    @State private var showInsufficientCoins = false
    @State private var isGenerating = false
    @State private var walletTargetGlobal: CGPoint? = nil
    // @State private var rewardCount: Double = 0   // no longer used
    @State private var coinFly = false
    @StateObject private var soundFX = SoundEffects.shared



    private func handleBack() {
        game.persistAllSafe()   // ensure snapshot is written
        dismiss()
    }

    // MARK: - Main Body
    var body: some View {
        
        ZStack {

            boardLayer
                .modifier(FreezeAnimations(active: showWorldBanner)) // <- board never shifts
                .overlay(alignment: .center) { auraOverlay }   // UNDER banner
                .overlay(alignment: .center) { bannerOverlay } // OVER aura
                .onDisappear {
                    game.persistAllSafe()   // saves achievement totals + current run snapshot
                }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showWorldBanner)
        .navigationBarBackButtonHidden(true)

        .onAppear {
            guard !didStart else { return }
            didStart = true
            startNewSession()
        }

        .onAppear { music.enterGame() }   // MusicCenter will pause for game
        .onDisappear { music.enterMenu() } // resumes when leaving gameplay

        
        // World word completed → show banner
        .onChange(of: game.worldWordJustCompleted) { _, justCompleted in
            guard justCompleted else { return }
            triggerWorldBanner()
        }

        .onChange(of: game.solved) { _, isSolved in
            guard isSolved && game.isLevelMode else { return }

            // Compute reward up front (don’t credit yet)
            let payout = levels.rewardCoins(for: game.moveCount, par: par)
            pendingRewardCoins = max(0, payout.total)

            // If the world banner is up, wait a touch so we don't overlap
            let presentFinishLottie = {
                finishStopIndex = 0
                showFinishLottie = true
            }

            if showWorldBanner || pendingWinDelay {
                pendingWinDelay = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    pendingWinDelay = false
                    presentFinishLottie()
                }
            } else {
                presentFinishLottie()
            }
        }



        .overlay(generatingOverlay)

        .overlay {
            if showFinishLottie {
                ZStack {
                    Color.black.opacity(0.22).ignoresSafeArea()

                    WorldLottiePlayer(
                        name: "Finished Animation 01",
                        stops: [0, 1],                   // straight through
                        index: $finishStopIndex,
                        onFinished: {
                            // 1) Dismiss finish animation
                            showFinishLottie = false
                            // 2) Then present your existing win panel (with Continue)
                            DispatchQueue.main.async {
                                withAnimation(.spring()) { showWin = true }
                            }
                        }
                    )
                    .scaleEffect(UIDevice.current.userInterfaceIdiom == .phone ? 1.4 : 1.2)
                    .contentShape(Rectangle())
                    // Optional: allow tap-to-skip to end
                    // .onTapGesture { finishStopIndex = 1 }
                }
                .onAppear {
                    Task { @MainActor in
                        SoundEffects.shared.play("WonLevel.m4a", volume: 0.8)
                    }
                }
                .transition(.opacity)
                .zIndex(115)
            }
        }

        
        // Simple win overlay (no coin value, just Continue)
        .overlay(winOverlay)

        // 🎁 Coin animation overlay (credits coins, then advances/ends)
        .overlay {
            if showCoinOverlay {
                CoinRewardOverlay(
                    isPresented: $showCoinOverlay,
                    amount: pendingRewardCoins
                ) {
                    // 1) Credit coins exactly once
                    if pendingRewardCoins > 0 {
                        levels.addCoins(pendingRewardCoins)
                        pendingRewardCoins = 0
                    }

                    // 2) Close the win UI
                    showWin = false

                    // 3) Advance to next level (or exit if none)
                    if levels.hasNextLevel(for: world) {
                        levels.advance(from: world)
                        startNewSession()
                    } else {
                        dismiss()
                    }
                }
                .zIndex(120)
            }
        }

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
        return boosts.remaining
    }

    private var canUseBoost: Bool {
        effectiveBoostsRemaining > 0 && !showWin && !showWorldBanner
    }

    private func onBoostConsumed() {
        if boostTest > 0 {
            boostTest -= 1
        } else {
            // _ = boosts.useOne()
        }
    }

//    @ViewBuilder
//    private func boostTile(icon: String, title: String, material: Material) -> some View {
//        VStack(spacing: 8) {
//            ZStack {
//                RoundedRectangle(cornerRadius: 14, style: .continuous)
//                    .fill(material)
//                    .frame(width: 88, height: 88)
//
//                Image(systemName: icon)
//                    .font(.system(size: 28, weight: .semibold))
//                    .foregroundStyle(.primary)
//            }
//            Text(title)
//                .font(.footnote.weight(.semibold))
//                .foregroundStyle(.primary)
//        }
//    }

    // MARK: - Layers

    @ViewBuilder private var boardLayer: some View {
        ContentView(
            world: world,
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
            .fixedSize()
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
            let w = (bannerSize == .zero ? 260 : bannerSize.width)  + 100
            let h = (bannerSize == .zero ?  90 : bannerSize.height) + 100

            ParticleAura()
                .frame(width: w, height: h)
                .opacity(0.9)
                .allowsHitTesting(false)
                .zIndex(9)
                .transition(.opacity)
        }
    }

    @ToolbarContentBuilder private var levelToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Text("\(world.name) | L\(levels.levelIndex(for: world) + 1)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(1.5)
                .foregroundStyle(Color.black)
        }
    }

    @ViewBuilder private var winOverlay: some View {
        if showWin {
            ZStack {
                // Dim background
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)

                // Confetti aura (behind the panel)
                ParticleAura()
                    .opacity(0.9)
                    .allowsHitTesting(false)

                // Panel: simple headline + Continue
                VStack(spacing: 18) {
                    Text("Level Complete!")
                        .font(.title).bold()

                    let hasNext = levels.hasNextLevel(for: world)

                    Button {
                        soundFX.playChestOpenSequence()
                        // 1) Hide the win sheet so it won't sit behind the Lottie
                        withAnimation(.easeOut(duration: 0.2)) {
                            showWin = false
                        }
                        // 2) Present the coin overlay on next tick
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            showCoinOverlay = true
                        }
                    } label: {
                        Text("Collect Reward!")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftRaisedPillStyle(height: 48))
                    .accessibilityLabel(Text(hasNext ? "Continue to next level" : "Continue"))
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }


    // MARK: - Helpers

    private struct FreezeAnimations: ViewModifier {
        let active: Bool
        func body(content: Content) -> some View {
            content.transaction { tx in
                if active { tx.animation = nil }
            }
        }
    }

//    private func buyRevealBoost(cost: Int, count: Int = 1) {
//        if levels.coins >= cost {
//            levels.addCoins(-cost)
//            boosts.grant(count: count)
//            #if os(iOS)
//            UIImpactFeedbackGenerator(style: .light).impactOccurred()
//            #endif
//        } else {
//            showInsufficientCoins = true
//        }
//    }

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
        levels.loadProgressIfNeeded()

        let idx  = levels.levelIndex(for: world)
        par      = levels.levelPar(for: world, levelIndex: idx)
        let seed = levels.seed(for: world, levelIndex: idx)

        print("▶️ Level entry — world=\(world.id) idx=\(idx) seed=\(seed)")

        // 🔑 Tell GameState which slot to use for this world+level
        game.levelSlotKey = RunKey.level(worldID: world.id, levelIndex: idx, seed: seed)

        // Reset view flags...
        showWin = false
        didAwardCoins = false
        bannerWasShown = false
        showWorldBanner = false
        pendingWinDelay = false

        isGenerating = true
        Task { @MainActor in
            await Task.yield()
            game.startLevelRun(
                seed: seed,
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
        } else if name.contains("tech") {
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
        if n.contains("tech")   { return .pink }
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
            Text("World Word Found!")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.90), radius: 4, x: 0, y: 1)
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
                        let band = max(56, w * 0.35)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.0), .white.opacity(0.28), .white.opacity(0.0)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: band, height: geo.size.height + 8)
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
        
        .onAppear {
            // Play sound effect when banner appears
            Task { @MainActor in
                SoundEffects.shared.play("WorldWordFound.m4a", volume: 0.8)
            }
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
