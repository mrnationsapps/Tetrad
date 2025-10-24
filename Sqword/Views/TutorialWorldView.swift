import SwiftUI
import UniformTypeIdentifiers

// Simple bouncy down arrow used as the coachmark.
private struct BouncyArrowDownSimple: View {
    // Knobs
    var xOffset: CGFloat = 84        // + moves right from horizontal center, – moves left
    var yOffset: CGFloat = 0        // baseline vertical offset (negative lifts it up)
    var bounce: CGFloat = 10        // bounce distance
    var color: Color = .yellow       // arrow color

    @State private var phase: CGFloat = 0

    var body: some View {
        // This view expands to the container's width, so the arrow starts centered.
        ZStack {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(color)
                .shadow(radius: 4, y: 2)
                // centered horizontally, then nudged by xOffset; vertical = yOffset + bounce phase
                .offset(x: xOffset, y: yOffset + phase)
        }
        .frame(maxWidth: .infinity) // ensures horizontal centering baseline
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                phase = bounce
            }
        }
    }
}


// MARK: - Tutorial World (scripted, two steps)
struct TutorialWorldView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var levels: LevelsService

    let world: World   // pass the Tutorial world

    enum Step { case intro, level1, level1Win, level2, level2Win }
    @State private var step: Step = .intro

    // Ensure L1Step is declared somewhere accessible:
    // enum L1Step: Equatable { case placeFirst, explainCost, promptBoost, done }
    @State private var l1Step: L1Step = .placeFirst

    @State private var lastAwardedCoins: Int = 0
    @State private var l1PlacedOne = false
    @State private var showRevealTip = false
    @State private var tutorialAllowsBoosts = false
    @State private var showInsufficientCoins = false
    @State private var showCoins = false

    @State private var showCoinOverlay = false
    @State private var isContinueDisabled = false

    private let kTutorialCompleted = "ach.tutorial.completed"

    private var l1StepContent: (index: Int, text: String)? {
        guard step == .level1 else { return nil }
        switch l1Step {
        case .placeFirst:   return (1, "Drag tiles onto the board to make words.")
        case .explainCost:  return (2, "Any further moves with that tile will cost a MOVE point.")
        case .promptBoost:  return (3, "Tap the Boosts button to use a Reveal!")
        case .done:         return nil
        }
    }

    private func markTutorialCompleted() {
        UserDefaults.standard.set(true, forKey: kTutorialCompleted)
        NotificationCenter.default.post(name: .achievementsChanged, object: nil)
    }

    private func handleTutorialContinue() {
        guard !isContinueDisabled else { return }
        isContinueDisabled = true
        if lastAwardedCoins > 0 {
            showCoinOverlay = true
        } else {
            goToNextTutorialLevel()
        }
    }

    // Called after the coin animation completes
    private func goToNextTutorialLevel() { dismiss() }

    var body: some View {
        ZStack {
            
            HStack{
                HStack{
                    Button { dismiss() }
                    label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left").imageScale(.medium)
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(SoftRaisedPillStyle(height: 40))
                    .opacity(0.5)
                    .frame(width: 60)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .safeAreaPadding(.top)      // adds the device's top safe area
                    .padding(.top, 40)          // + your extra nudge
                    .padding(.leading, 16)
                    
                    Spacer()

                    Text("SQWORD")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundColor(.white)
                        .opacity(0.5)
                        .safeAreaPadding(.top)
                        .padding(.top, 44)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(x: -48, y: 0)

                    Color.clear.frame(width: 60)
                }
                .ignoresSafeArea(edges: .top)
                .navigationBarBackButtonHidden(true)
                
            }

            switch step {
            case .intro:
                IntroLesson(onContinue: { step = .level1 })

            case .level1:
                TutorialLevelScreen(
                    title: "\(world.name) – Level 1",
                    streak: 1,
                    order: 2,
                    dictionaryName: "Tutorial_Order2Dictionary",
                    showHelpers: true,
                    l1Step: $l1Step,
                    onFirstPlacement: { l1Step = .explainCost },
                    onRequestBoosts: { /* no-op; handled via footer */ },
                    onWin: {
                        let awarded = levels.awardCoinsIfAllowedInTutorial(3)
                        lastAwardedCoins = awarded
                        step = .level1Win
                    },
                    onSecondPlacement: { l1Step = .promptBoost }
                )

            case .level1Win:
                WinSheet(
                    message: lastAwardedCoins > 0 ? "" : "",
                    primary: ("Continue", {
                        if lastAwardedCoins > 0 {
                            showCoinOverlay = true
                        } else {
                            step = .level2
                        }
                    }),
                    secondary: nil
                )

            case .level2:
                TutorialLevelScreen(
                    title: "\(world.name) – Level 2",
                    streak: 2,
                    order: 3,
                    dictionaryName: "Tutorial_Order3Dictionary",
                    showHelpers: false,
                    l1Step: .constant(.done),
                    onFirstPlacement: {},
                    onRequestBoosts: {},
                    onWin: {
                        let awarded = levels.awardCoinsIfAllowedInTutorial(3, markCompletedIfFinal: true)
                        lastAwardedCoins = awarded
                        markTutorialCompleted()
                        step = .level2Win
                        UserDefaults.standard.set(true, forKey: "tutorial.finished.once")
                    }
                )

            case .level2Win:
                WinSheet(
                    message: lastAwardedCoins > 0 ? "" : "",
                    primary: ("Continue", {
                        if lastAwardedCoins > 0 {
                            showCoinOverlay = true
                        } else {
                            dismiss()
                        }
                    }),
                    secondary: nil
                )
            }
        }
        .background {
            Image("Sqword-Splash")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .navigationBarBackButtonHidden(true)

        // Coin overlay
        .overlay {
            if showCoinOverlay {
                CoinRewardOverlay(
                    isPresented: $showCoinOverlay,
                    amount: lastAwardedCoins
                ) {
                    if step == .level1Win { step = .level2 }
                    else if step == .level2Win { dismiss() }
                }
            }
        }

        // Instruction callout (bottom, centered)
        .overlay(alignment: .bottom) {
            Group {
                if let stepLine = l1StepContent {
                    HStack {
                        Spacer()
                        CalloutCard {
                            numberedStep(stepLine.index, stepLine.text)
                        }
                        .frame(maxWidth: 520)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if step == .level2 {
                    HStack {
                        Spacer()
                        CalloutCard {
                            Text("Now try a 3×3, same rules.\nBoosts are available anytime, but are limited in the real game.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.92))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: 520)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .offset(y: 80)
                }
            }
        }


        // Gate Boosts when Level 1 reaches “Tap Boosts…”
        .onChange(of: l1Step) { _, newStep in
            if step == .level1 {
                tutorialAllowsBoosts = (newStep == .promptBoost)
            }
        }

        
        
        
        
//        // Top toolbar
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button {
//                    dismiss()
//                } label: {
//                    HStack(spacing: 6) {
//                        Image(systemName: "chevron.left").imageScale(.medium)
//                        Text("Back")
//                    }
//                }
//                .buttonStyle(SoftRaisedPillStyle(height: 36))
//            }
//            ToolbarItem(placement: .principal) {
//                Text("TUTORIAL")
//                    .font(.system(size: 22, weight: .heavy, design: .rounded))
//                    .tracking(1.5)
//            }
//        }

        // Footer panels
        .withFooterPanels(
            coins: nil,
            boostsAvailable: nil,
            isInteractable: (step == .level2) || (step == .level1 && tutorialAllowsBoosts),
            disabledStyle: .ghosted,
            boostsPanel: { dismiss in
                let boostsEnabled = (step == .level2) || (step == .level1 && tutorialAllowsBoosts)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Label("Boosts", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(boostsEnabled ? "Unlimited" : "Follow the steps first")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            NotificationCenter.default.post(name: .tutorialRevealRequested, object: nil)
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            dismiss()
                        } label: {
                            boostTile(icon: "wand.and.stars", title: "Reveal", material: .thinMaterial)
                        }
                        .buttonStyle(.plain)
                        .disabled(!boostsEnabled)
                        .opacity(boostsEnabled ? 1.0 : 0.4)
                        .alignmentGuide(.top) { d in d[.top] }

                        boostTile(icon: "arrow.left.arrow.right", title: "Swap", material: .thinMaterial)
                            .opacity(0.35)
                            .alignmentGuide(.top) { d in d[.top] }

                        boostTile(icon: "eye", title: "Clarity", material: .thinMaterial)
                            .opacity(0.35)
                            .alignmentGuide(.top) { d in d[.top] }
                            .padding(.top, 10)
                    }
                }
            },
            walletPanel: { _ in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Wallet", systemImage: "creditcard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                            Text("\(levels.coins)").font(.headline).monospacedDigit()
                        }
                    }
                    Text("You’ll start earning and spending coins after the tutorial.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        )

        // Arrow coachmark: draw it near the bottom-right, offset to hover above the Boosts pill.
        // No anchors or preference keys required.
        .overlay(alignment: .bottomTrailing) {
            let showArrow = (step == .level1 && l1Step == .promptBoost)
            if showArrow {
                // ⬇️ Tweak these to align with your footer pill position
                let rightPadding: CGFloat = 24   // match your screen horizontal padding
                let aboveFooter: CGFloat  = 76   // ~ pillHeight(44) + footer vertical padding
                BouncyArrowDownSimple()
                    .padding(.trailing, rightPadding)
                    .padding(.bottom, aboveFooter)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Small helpers
@ViewBuilder
private func numberedStep(_ n: Int, _ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(text)
            .foregroundStyle(.white.opacity(0.92))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(10)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
    }
}

private struct CalloutCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
//            .padding(.vertical, 10)
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(Color.softSage.opacity(1.0))
//            )
//            .overlay(
//                RoundedRectangle(cornerRadius: 12)
//                    .stroke(.white, lineWidth: 1)
//            )
            .shadow(radius: 6, x: 0, y: 2)
            .padding(.horizontal, 20)
            .offset(y: 20)
    }
}

private struct IntroLesson: View {
    var onContinue: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            (Text("Sqword is a square word puzzle."))
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .foregroundColor(.white)

            Text("The first column is equal to the first row. The second column, the second row, etc.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .foregroundColor(.white)


            StaticSquare3x3(rows: ["BIT","ICE","TEN"])
                .padding(.top, 4)

            Text("Both columns and rows spell the words BIT, ICE & TEN.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.top, 2)
                .foregroundColor(.white)

            Button(action: onContinue) {
                Text("Let's try one")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftRaisedPillStyle(height: 52))
            .padding(.top, 16)
        }
        .padding(24)
        .padding(.top, 40)
    }
}

private struct StaticSquare3x3: View {
    let rows: [String]
    var body: some View {
        let letters = rows.map(Array.init)
        let corner: CGFloat = 10

        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { c in
                        ZStack {
                            RoundedRectangle(cornerRadius: corner)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: corner)
                                        .stroke(.secondary, lineWidth: 1)
                                )

                            Text(String(letters[r][c]))
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 64, height: 64)
                        .shadow(radius: 1, x: 0, y: 1)
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Win Sheet
private struct WinSheet: View {
    let message: String
    let primary: (String, () -> Void)
    let secondary: (String, () -> Void)?
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Well done!").font(.title).bold()
                Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    if let secondary = secondary {
                        Button(secondary.0, action: secondary.1)
                            .buttonStyle(SoftRaisedPillStyle(height: 48))
                    }
                    Button(primary.0, action: primary.1)
                        .buttonStyle(SoftRaisedPillStyle(height: 48))
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Shared tiny tile used in the panels
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

extension Notification.Name {
    static let achievementsChanged = Notification.Name("achievementsChanged")
}
