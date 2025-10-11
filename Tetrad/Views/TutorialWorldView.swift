//
//  TutorialWorldView.swift
//  Tetrad
//
//  Created by kevin nations on 10/3/25.
//
// TutorialWorldView.swift

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Tutorial World (scripted, two steps)
struct TutorialWorldView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var levels: LevelsService
    // If you want Wallet to function here later (coins purchases), you can also:
    // @EnvironmentObject private var boosts: BoostsService
    // @EnvironmentObject private var game: GameState

    let world: World   // pass the Tutorial world

    enum Step { case intro, level1, level1Win, level2, level2Win }
    @State private var step: Step = .intro

    // inside struct TutorialWorldView
    @State private var l1Step: L1Step = .placeFirst
    @State private var lastAwardedCoins: Int = 0   // ← NEW: tracks what we actually granted

    private var l1StepContent: (index: Int, text: String)? {
        guard step == .level1 else { return nil }
        switch l1Step {
        case .placeFirst:   return (1, "Drag tiles onto the board to make words.")
        case .explainCost:  return (2, "Any further moves with that tile will cost a MOVE point.")
        case .promptBoost:  return (3, "Tap the Boosts button to use a Reveal!")
        case .done:         return nil
        }
    }

    @State private var l1PlacedOne = false
    // Old sheet path removed in favor of footer panels:
    // @State private var showBoostSheet = false
    @State private var showRevealTip = false
    @State private var tutorialAllowsBoosts = false   // flips true when we reach Step 3 (“Tap Boosts…”)
    @State private var showInsufficientCoins = false  // if you later enable wallet purchases here

    var body: some View {
        ZStack {
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
                    // 1st tile placed → advance to step 2
                    onFirstPlacement: { l1Step = .explainCost },
                    // (Old) onRequestBoosts used to show a sheet; keep as a no-op now.
                    onRequestBoosts: { /* handled via footer Boosts panel */ },
                    onWin: {
                        // FIRST tutorial level: award coins only if allowed (first-ever run)
                        let awarded = levels.awardCoinsIfAllowedInTutorial(3)
                        lastAwardedCoins = awarded
                        step = .level1Win
                    },
                    // 2nd tile placed → advance to step 3
                    onSecondPlacement: { l1Step = .promptBoost }
                )

            case .level1Win:
                WinSheet(
                    message: lastAwardedCoins > 0
                        ? "You've got it! Collect 3 coins!\nMove on to Level 2"
                        : "Move on to Level 2",
                    primary: ("Continue", { step = .level2 }),
                    secondary: ("Quit", { dismiss() })
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
                        // FINAL tutorial level: award if allowed, and mark tutorial completed
                        let awarded = levels.awardCoinsIfAllowedInTutorial(3, markCompletedIfFinal: true)
                        lastAwardedCoins = awarded
                        step = .level2Win
                    }
                )

            case .level2Win:
                WinSheet(
                    message: lastAwardedCoins > 0
                        ? "You've got it! Collect 3 coins!"
                        : "",
                    primary: ("Continue", { dismiss() }),
                    secondary: nil
                )
            }
        }
        .navigationBarBackButtonHidden(true) //hides the system back button

        // ⬇️ Instruction Callout Text (L1) + L2 hint
        .overlay(alignment: .bottomTrailing) {
            Group {
                if let stepLine = l1StepContent {
                    CalloutCard {
                        numberedStep(stepLine.index, stepLine.text)   // L1
                    }
                    .frame(maxWidth: 420)
                    .padding(.trailing, 0)
                    .padding(.bottom, 120)   // sits above footer pills
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if step == .level2 {
                    CalloutCard {
                        Text("Now try a 3×3, same rules.\nBoosts are available anytime, but are limited in the real game.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.92)) // was .secondary

                    }
                    .frame(maxWidth: 420)
                    .padding(.trailing, 0)
                    .padding(.bottom, 120)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .offset(y: 80)
                }
            }
        }

        // 🔔 Flip the Boosts gate ON when Level 1 reaches the “Tap Boosts…” step
        .onChange(of: l1Step) { _, newStep in
            if step == .level1 {
                tutorialAllowsBoosts = (newStep == .promptBoost)
            }
        }

        // 🧭 Top toolbar (unchanged)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").imageScale(.medium)
                        Text("Back")
                    }
                }
                .buttonStyle(SoftRaisedPillStyle(height: 36))
            }
            ToolbarItem(placement: .principal) {
                Text("TUTORIAL")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .tracking(1.5)
            }
//            ToolbarItem(placement: .navigationBarTrailing) {
//                HStack(spacing: 6) {
//                    Image(systemName: "dollarsign.circle.fill").imageScale(.large)
//                    Text("\(levels.coins)").font(.headline).monospacedDigit()
//                }
//                .softRaisedCapsule()
//            }
        }

        // 👇 Footer + Panels for Tutorial (Boosts gated to Step 3; Wallet read-only)
        .withFooterPanels(
            coins: nil,
            boostsAvailable: nil,
            // ✅ Footer is interactable if: L2 OR (L1 and we’ve reached the Boost step)
            isInteractable: (step == .level2) || (step == .level1 && tutorialAllowsBoosts),
            disabledStyle: .ghosted,
            boostsPanel: { dismiss in
                // Gate button enablement the same way
                let boostsEnabled = (step == .level2) || (step == .level1 && tutorialAllowsBoosts)

                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack(alignment: .top) {
                        Label("Boosts", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(boostsEnabled ? "Unlimited" : "Follow the steps first")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    // Tiles row
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

                        // placeholders
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
            walletPanel: { dismiss in
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

        // If you add purchases in tutorial later:
        .alert("Not enough coins", isPresented: $showInsufficientCoins) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You don't have enough coins for that purchase.")
        }
    }
}

// MARK: - Small helpers

@ViewBuilder
private func numberedStep(_ n: Int, _ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(text)
            .foregroundStyle(.white.opacity(0.92)) // was .secondary
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(10)
            .multilineTextAlignment(.center)
    }
}

private struct CalloutCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.softSage.opacity(1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white, lineWidth: 1)   // ← white stroke
            )
            .shadow(radius: 6, x: 0, y: 2)
            .padding(.horizontal, 20)
            .offset(y: 20)
    }

}

private struct IntroLesson: View {
    var onContinue: () -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                (Text("TETRAD is based on the age-old \n")
                 + Text("word square puzzle.").italic())
                //.font(.system(size: 18))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

                (Text("What's a Word Square?"))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text("A word square is a grid where column n is the same as row n.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                StaticSquare3x3(rows: ["BIT","ICE","TEN"])
                    .padding(.top, 4)

                Text("Notice how Row 1 = Column 1, Row 2 = Column 2, etc.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                Button(action: onContinue) {
                    Text("Let's try one")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftRaisedPillStyle(height: 52))
                .padding(.top, 16)
            }
            .padding(24)
        }
    }
}

private struct StaticSquare3x3: View {
    let rows: [String]  // 3 strings of length 3
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16)) // keep or remove if you prefer flat
    }
}


// MARK: - Overlays

private struct WinSheet: View {
    let message: String
    let primary: (String, () -> Void)
    let secondary: (String, () -> Void)?
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("You got it!").font(.title).bold()
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
