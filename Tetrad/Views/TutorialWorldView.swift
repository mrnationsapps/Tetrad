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

    let world: World   // pass the Tutorial world

    enum Step { case intro, level1, level1Win, level2, level2Win }
    @State private var step: Step = .intro

    // inside struct TutorialWorldView
    @State private var l1Step: L1Step = .placeFirst

    private var l1StepContent: (index: Int, text: String)? {
        guard step == .level1 else { return nil }
        switch l1Step {
        case .placeFirst:   return (1, "Drag tiles onto the board to make words.")
        case .explainCost:  return (2, "Any further moves with that tile will cost a MOVE point.")
        case .promptBoost:  return (3, "Tap the Boosts button to use a Reveal, which will reveal a letter!")
        case .done:         return nil
        }
    }


    // helper gating in L1
    @State private var l1PlacedOne = false
    @State private var showBoostSheet = false
    @State private var showRevealTip = false

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
                    onRequestBoosts: { showBoostSheet = true },
                    onWin: {
                        levels.addCoins(3)
                        step = .level1Win
                    },
                    // 2nd tile placed → advance to step 3
                    onSecondPlacement: { l1Step = .promptBoost }
                )

            case .level1Win:
                WinSheet(
                    message: "You've got it! Collect 3 coins!\nMove on to Level 2",
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
                        levels.addCoins(3)
                        step = .level2Win
                    }
                )

            case .level2Win:
                WinSheet(
                    message: "You've got it! Collect 3 coins!",
                    primary: ("Continue", { dismiss() }),
                    secondary: nil
                )
            }
        }
        // ⬇️ Instruction Callout Text
        .overlay(alignment: .bottomTrailing) {
            Group {
                if let stepLine = l1StepContent {
                    CalloutCard {
                        // exactly one numbered line at a time
                        numberedStep(stepLine.index, stepLine.text)
                    }
                    .frame(maxWidth: 420)
                    .padding(.trailing, 16) // align with Boosts pill trailing inset
                    .padding(.bottom, 120)   // sit just above the Boosts pill
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }

        .sheet(isPresented: $showBoostSheet) {
            VStack(spacing: 16) {
                Text("Boosts").font(.title2).bold()
                Text("Tap “Reveal” to reveal a hidden letter.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button {
                    NotificationCenter.default.post(name: .tutorialRevealRequested, object: nil)
                    showBoostSheet = false
                    showRevealTip = false
                } label: {
                    Label("Reveal", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftRaisedPillStyle(height: 48))

                Button("Close") { showBoostSheet = false }
                    .padding(.top, 8)
            }
            .padding(20)
            .presentationDetents([.height(260)])
        }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                    Text("\(levels.coins)").font(.headline).monospacedDigit()
                }
                .softRaisedCapsule()
            }
        }
    }


}

@ViewBuilder
private func numberedStep(_ n: Int, _ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: "\(n).circle.fill")
            .font(.title3)
            .foregroundStyle(.tint)                 // <- or Color.accentColor
        Text(text)
            .font(.headline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CalloutCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 6, x: 0, y: 2)
    }
}


private struct IntroLesson: View {
    var onContinue: () -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("What’s a Word Square?")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                Text("A word square is a grid where column n is the same as row n.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                StaticSquare3x3(rows: ["BIT","ICE","TEN"])
                    .padding(.top, 4)

                Text("Notice how ROW 1 = COLUMN 1, ROW 2 = COLUMN 2, etc.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                Button(action: onContinue) {
                    Text("Continue")
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
        let letters = rows.map { Array($0) }
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [.purple.opacity(0.85), .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(
                                Text(String(letters[r][c]))
                                    .font(.system(size: 26, weight: .heavy))
                                    .foregroundStyle(.white)
                            )
                            .frame(width: 64, height: 64)
                            .shadow(radius: 6, x: 0, y: 4)
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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

