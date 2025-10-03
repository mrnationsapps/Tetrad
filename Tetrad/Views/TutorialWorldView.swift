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
                    onFirstPlacement: { l1PlacedOne = true; showRevealTip = true },
                    onRequestBoosts: { showBoostSheet = true },
                    onWin: {
                        levels.addCoins(3)
                        step = .level1Win
                    }
                ) // ← no board overlay passed; we’ll place tips at screen bottom

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
        // ⬇️ Screen-level overlay: bottom-right, just above the Boosts pill
        .overlay(alignment: .bottomTrailing) {
            Group {
                // Level 1 – initial two-step helper
                if step == .level1, !l1PlacedOne {
                    CalloutCard {
                        VStack(alignment: .leading, spacing: 8) {
                            numberedStep(1, "Drag tiles onto the board to make words.")
                            numberedStep(2, "Any further moves with that tile will cost a MOVE point.")
                        }
                    }
                    .frame(maxWidth: 420)
                    .padding(.trailing, 16) // align with Boosts pill trailing inset
                    .padding(.bottom, 76)   // sit just above the Boosts pill
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Level 1 – Boost tip after first placement
                if step == .level1, showRevealTip {
                    CalloutCard {
                        numberedStep(3, "Tap the Boosts button to reveal a helpful letter.")
                    }
                    .frame(maxWidth: 360)
                    .padding(.trailing, 16)
                    .padding(.bottom, 76)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .onAppear { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
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
            .font(.subheadline)
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

// MARK: - Level Screen (mini-engine for order 2/3)

private struct TutorialLevelScreen<BoardOverlay: View>: View {
    let title: String
    let streak: Int
    let order: Int
    let dictionaryName: String
    let showHelpers: Bool
    let onFirstPlacement: () -> Void
    let onRequestBoosts: () -> Void
    let onWin: () -> Void

    // 🔹 Caller-provided overlay content rendered over the board zone
    let overlay: BoardOverlay
    init(
        title: String,
        streak: Int,
        order: Int,
        dictionaryName: String,
        showHelpers: Bool,
        onFirstPlacement: @escaping () -> Void,
        onRequestBoosts: @escaping () -> Void,
        onWin: @escaping () -> Void,
        @ViewBuilder overlay: () -> BoardOverlay = { EmptyView() }
    ) {
        self.title = title
        self.streak = streak
        self.order = order
        self.dictionaryName = dictionaryName
        self.showHelpers = showHelpers
        self.onFirstPlacement = onFirstPlacement
        self.onRequestBoosts = onRequestBoosts
        self.onWin = onWin
        self.overlay = overlay()
    }

    @State private var model = MiniSquareGame()
    @State private var didPlaceOnce = false

    // tweak if your real board uses different values
    private let refGap: CGFloat = 8
    private let minCell: CGFloat = 36
    private let maxCell: CGFloat = 120
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // HUD (top-right)
                HStack {
                    Spacer()
                    Text("Moves: \(model.moves)    Streak: \(streak)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 14)
                .fixedSize(horizontal: false, vertical: true)

                // BOARD ZONE: cap to a 3×3 footprint, keep tile size = real 4×4
                GeometryReader { geo in
                    // 1) Compute tile size from width as if rendering a 4×4 board
                    let usableWidth = geo.size.width - horizontalPadding * 2
                    let refCell = clamp(((usableWidth - 3 * refGap) / 4).rounded(.down),
                                        min: minCell, max: maxCell)

                    // 2) Reserve only a 3×3 footprint for the tutorial zone
                    let zoneWidth4  = refCell * 4 + refGap * 3   // full width feel
                    let zoneHeight3 = refCell * 3 + refGap * 2   // height capped to 3×3

                    ZStack(alignment: .top) {
                        // Invisible board zone (positions everything)
                        Color.clear
                            .frame(width: zoneWidth4, height: zoneHeight3)
                            .overlay(alignment: .center) {
                                
                                // 2×2 or 3×3 board, top-centered, using SAME tile size
                                MiniBoardView(
                                    model: $model,
                                    order: order,
                                    cell: refCell,
                                    gap: refGap
                                ) { didMove in
                                    if didMove && !didPlaceOnce {
                                        didPlaceOnce = true
                                        onFirstPlacement()
                                    }
                                    if model.isSolved {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onWin() }
                                    }
                                }
                                .id(order)
                            }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        //.padding(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))


                        // 🔹 Caller overlay drawn over the board zone
                        overlay
                            .allowsHitTesting(false)
                            .transition(.opacity)
                            .zIndex(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, horizontalPadding)
                    // 3) Constrain the whole block to the 3×3 height
                    .frame(height: zoneHeight3)
                }
                .padding(.top, 14)

                // LETTER BAG
                VStack(alignment: .leading, spacing: 8) {
                    Text("Letter Bag")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    MiniBagView(model: $model)
                        .padding(.horizontal, horizontalPadding)
                        //.padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Floating Boosts pill bottom-trailing
            if showHelpers {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: onRequestBoosts) {
                            Label("Boosts", systemImage: "sparkles")
                                .font(.headline)
                                .padding(.horizontal, 14)
                        }
                        .buttonStyle(SoftRaisedPillStyle(height: 44))
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .onAppear {
            model.load(order: order, dictionaryName: dictionaryName)
            NotificationCenter.default.addObserver(forName: .tutorialRevealRequested, object: nil, queue: .main) { _ in
                model.revealOne()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .tutorialRevealRequested, object: nil)
        }
    }

    private func clamp(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        max(lo, min(v, hi))
    }
}




private extension Notification.Name {
    static let tutorialRevealRequested = Notification.Name("tutorialRevealRequested")
}

// MARK: - Mini engine

private struct MiniSquareGame {
    struct Cell: Hashable { var r: Int; var c: Int }
    var order: Int = 2
    var solution: [String] = []
    var board: [[Character?]] = []
    var locked: Set<Cell> = []        // for reveal/lock
    var bag: [Character] = []
    var moves: Int = 0

    var isSolved: Bool {
        guard board.count == order else { return false }
        for r in 0..<order {
            for c in 0..<order {
                guard let ch = board[r][c] else { return false }
                let want = Array(solution[r])[c]
                if ch != want { return false }
            }
        }
        return true
    }

    mutating func load(order: Int, dictionaryName: String) {
        self.order = order
        // Try bundle text (one word square per line, e.g., "APE,PEA,EAR")
        if let squares = loadSquaresFromBundle(named: dictionaryName), let pick = squares.randomElement() {
            solution = pick
        } else {
            solution = fallbackSquare(order: order)
        }

        board = Array(repeating: Array(repeating: nil, count: order), count: order)
        locked.removeAll()

        // bag is the multiset of solution letters
        bag = solution.flatMap { Array($0) }.shuffled()
        moves = 0
    }

    mutating func place(_ ch: Character, at cell: Cell) -> Bool {
        guard locked.contains(cell) == false else { return false }
        // remove from bag first occurrence
        if let idx = bag.firstIndex(of: ch) {
            bag.remove(at: idx)
            if board[cell.r][cell.c] != nil { moves += 1 } // replacing costs a move
            board[cell.r][cell.c] = ch
            // Optional: count first placements as moves too
            moves += 1
            return true
        }
        return false
    }

    mutating func clear(at cell: Cell) {
        guard locked.contains(cell) == false else { return }
        if let ch = board[cell.r][cell.c] {
            bag.append(ch)
            board[cell.r][cell.c] = nil
            moves += 1
        }
    }

    mutating func revealOne() {
        // find an empty cell, fill with correct char, lock it
        var empties: [Cell] = []
        for r in 0..<order {
            for c in 0..<order {
                if board[r][c] == nil {
                    empties.append(Cell(r: r, c: c))
                }
            }
        }
        guard let target = empties.randomElement() else { return }
        let want = Array(solution[target.r])[target.c]
        // remove that letter from bag
        if let idx = bag.firstIndex(of: want) {
            bag.remove(at: idx)
        }
        board[target.r][target.c] = want
        locked.insert(target)
        // tiny move penalty to match “boosts cost moves”
        moves += 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: loading helpers

    private func loadSquaresFromBundle(named: String) -> [[String]]? {
        guard let url = Bundle.main.url(forResource: named, withExtension: "txt"),
              let text = try? String(contentsOf: url) else { return nil }
        // each non-empty line: words separated by comma or whitespace
        let lines = text.split(whereSeparator: \.isNewline)
        let squares: [[String]] = lines.compactMap { line in
            let parts = line.split { ", \t".contains($0) }.map { String($0).uppercased() }
            let n = parts.first?.count ?? 0
            guard n > 0, parts.count == n, parts.allSatisfy({ $0.count == n }) else { return nil }
            return parts
        }
        return squares.isEmpty ? nil : squares
    }

    private func fallbackSquare(order: Int) -> [String] {
        if order == 2 {
            return ["AT","TO"] // classic 2×2
        } else {
            // a couple of known 3×3 squares
            let options = [
                ["APE","PEA","EAR"],
                ["EAT","ARE","TEA"]
            ]
            return options.randomElement()!
        }
    }
}

// MARK: - Mini board + bag UI (simple and sturdy)

private struct MiniBoardView: View {
    @Binding var model: MiniSquareGame
    let order: Int
    let cell: CGFloat           // ← exact tile side (matches real board)
    let gap: CGFloat            // ← same gap as real board
    var onAnyMove: (_ didMove: Bool) -> Void

    var body: some View {
        let boardSize = cell * CGFloat(order) + gap * CGFloat(order - 1)
        let cols = Array(repeating: GridItem(.fixed(cell), spacing: gap), count: order)

        // model ready?
        let ready = model.board.count == order && model.board.allSatisfy { $0.count == order }

        LazyVGrid(columns: cols, spacing: gap) {
            ForEach(0..<(order * order), id: \.self) { i in
                let r = i / order
                let c = i % order

                TileCell(
                    char: safeChar(r, c),
                    locked: ready && model.locked.contains(.init(r: r, c: c)),
                    side: cell
                )
                .onTapGesture {
                    guard ready else { return }
                    if model.board[r][c] != nil {
                        model.clear(at: .init(r: r, c: c))
                        onAnyMove(true)
                    }
                }
                .onDrop(of: [.utf8PlainText, .plainText], isTargeted: nil) { providers in
                    guard ready, let item = providers.first else { return false }
                    _ = item.loadObject(ofClass: NSString.self) { reading, _ in
                        guard let ns = reading as? NSString,
                              let ch = (ns as String).first else { return }
                        DispatchQueue.main.async {
                            let moved = model.place(ch, at: .init(r: r, c: c))
                            onAnyMove(moved)
                        }
                    }
                    return true
                }
            }
        }
        .frame(width: boardSize, height: boardSize, alignment: .top)
    }

    private func safeChar(_ r: Int, _ c: Int) -> Character? {
        guard r >= 0, c >= 0,
              r < model.board.count,
              c < model.board[r].count else { return nil }
        return model.board[r][c]
    }
}

private struct TileCell: View {
    let char: Character?
    let locked: Bool
    var side: CGFloat? = nil    // ← NEW: when provided, forces a square tile

    var body: some View {
        // unify the fill type so the ternary compiles
        let tileFill: AnyShapeStyle = locked
        ? AnyShapeStyle(
            LinearGradient(
                colors: [.purple.opacity(0.95), .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
          )
        : AnyShapeStyle(Color(.systemBackground))

        let corner: CGFloat = 10

        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(tileFill)
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .stroke(locked ? .white.opacity(0.85) : .secondary, lineWidth: 1)
                )

            if let ch = char {
                Text(String(ch))
                    .font(.system(size: 24, weight: .heavy))
            }
        }
        .frame(
            width:  side ??  nil,    // if side provided, use exact square
            height: side ??  nil
        )
        .frame(minWidth: side == nil ? 56 : nil,
               maxWidth: side == nil ? 96 : nil,
               minHeight: side == nil ? 56 : nil,
               maxHeight: side == nil ? 96 : nil)
        .shadow(radius: 1, x: 0, y: 1)
    }
}



private struct MiniBagView: View {
    @Binding var model: MiniSquareGame
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(model.bag.enumerated()), id: \.offset) { idx, ch in
                Text(String(ch))
                    .font(.system(size: 20, weight: .heavy))
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemBackground))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary, lineWidth: 1))
                    )
                    .onDrag { NSItemProvider(object: String(ch) as NSString) }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Overlays

private struct HelperOverlay: View {
    enum Arrow { case none, down }
    let text: String
    var arrow: Arrow = .none

    var body: some View {
        VStack(spacing: 12) {
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            if arrow == .down {
                Image(systemName: "arrow.down")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 16)
        .padding(.bottom, 120)
        .transition(.opacity)
        .allowsHitTesting(false)
    }
}

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

