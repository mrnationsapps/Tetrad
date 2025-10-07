import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var levels: LevelsService

    var skipDailyBootstrap: Bool = false
    var par: Int? = nil
    var enableDailyWinUI: Bool = true   // ⬅️ new (default stays true for Daily)

    // TESTING ONLY.  DO NOT LEAVE ON RELEASE
    @State private var boardTest: Int = 0          // shifts day away from today
    @State private var boostTest: Int = 10         // adds boosts to your current number
    
    // MARK: Boosts
    @EnvironmentObject var boosts: BoostsService
    @State private var showBoostsPanel: Bool = false     // compact panel in the bag area
    private enum BoostMode { case none, smart }

    // selection (tap-to-place still supported)
    @State private var selectedTileID: UUID? = nil
    @State private var draggingTileID: UUID? = nil
    @State private var dragPoint: CGPoint = .zero
    @State private var currentBoardCell: CGFloat = 64
    @State private var boardGap: CGFloat = 0
    @State private var boardOriginInStage: CGPoint = .zero   // top-left of board in "stage" space
    @State private var ghostSize: CGSize = .init(width: 60, height: 60)
    @State private var tileScale: CGFloat = 1.0   // 1.0 = natural responsive size
    @State private var bagTileSize: CGFloat = 56   // smaller than the board tiles
    @State private var bagGap: CGFloat = 0         // spacing between bag tiles
    @State private var boardRect: CGRect = .zero
    @State private var bagRect:   CGRect = .zero
    // Shared space measurement for bag/panel
    @State private var bagHeight: CGFloat = 0
    @State private var boostsHeight: CGFloat = 0
    @State private var showWinPopup = false
    @State private var bagGridRect: CGRect = .zero   // precise hit area = LazyVGrid
    @State private var bagGridWidth: CGFloat = 0
    
    // TESTING HELPERS
    private var effectiveBoostsRemaining: Int {
        boosts.remaining + max(0, boostTest)
    }
    private var canUseBoost: Bool {
        effectiveBoostsRemaining > 0
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                header
                boardView
                underBoardRegion
            }
            .padding()

            // Ghost Tile
            if let id = draggingTileID,
               let tile = game.tiles.first(where: { $0.id == id }) {
                tileGhost(tile, size: ghostSize)
                    .frame(width: ghostSize.width, height: ghostSize.height)
                    .position(dragPoint)      // point is in "stage"
                    .allowsHitTesting(false)
            }

            // 🟢 Daily-only win popup (suppressed in Levels via enableDailyWinUI = false)
            if enableDailyWinUI && showWinPopup {
                // Dim background
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)

                // Centered popup
                VStack(spacing: 12) {
                    Text("You got it!")
                        .font(.title2).bold()

                    Button("Copy Win Info") {
                        UIPasteboard.general.string = game.shareString()
                        withAnimation(.spring()) { showWinPopup = false }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                )
                .shadow(radius: 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .coordinateSpace(name: "stage")       // shared space for board + bag + ghost

        .navigationBarTitleDisplayMode(.inline)   // keep everything on one compact row
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("TETRAD")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(x: 0)
            }
        }

        // Daily bootstrap stays gated by skipDailyBootstrap
        .onAppear {
            guard !skipDailyBootstrap else { return }
            let offsetDate = Calendar(identifier: .gregorian).date(
                byAdding: .day, value: boardTest, to: Date()
            ) ?? Date()
            game.bootstrapForToday(date: offsetDate)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard !skipDailyBootstrap else { return }
            if newPhase == .active {
                let offsetDate = Calendar(identifier: .gregorian).date(
                    byAdding: .day, value: boardTest, to: Date()
                ) ?? Date()
                game.bootstrapForToday(date: offsetDate)
            }
        }

        // Only trigger Daily win popup when enabled
        .onChange(of: game.solved) { _, isSolved in
            guard enableDailyWinUI else { return }
            if isSolved { withAnimation(.spring()) { showWinPopup = true } }
        }
        .onAppear { showWinPopup = false }  // ensure clean state on re-entry
        
        .withFooterPanels(
            coins: levels.coins,
            boostsAvailable: boosts.remaining,
            isInteractable: true,
            disabledStyle: .standard,
            boostsPanel: { dismiss in DailyBoostsPanel(dismiss: dismiss) },
            walletPanel: { dismiss in DailyWalletPanel(dismiss: dismiss) }
        )

    }

    // MARK: - Daily Boosts Panel (Reveal wired to GameState)
    private struct DailyBoostsPanel: View {
        @EnvironmentObject var game: GameState
        @EnvironmentObject var boosts: BoostsService
        let dismiss: () -> Void

        @State private var errorText: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(alignment: .top) {
                    Label("Boosts", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(boosts.remaining) left")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Tiles row
                HStack(alignment: .top, spacing: 12) {
                    // REVEAL (active)
                    Button(action: useSmartBoost) {
                        BoostTile(icon: "wand.and.stars", title: "Reveal")
                    }
                    .buttonStyle(.plain)
                    .disabled(boosts.remaining == 0)
                    .opacity(boosts.remaining == 0 ? 0.4 : 1.0)
                    .alignmentGuide(.top) { d in d[.top] }

                    // Placeholders
                    BoostTile(icon: "arrow.left.arrow.right", title: "Swap")
                        .opacity(0.35)
                        .alignmentGuide(.top) { d in d[.top] }

                    BoostTile(icon: "eye", title: "Clarity")
                        .opacity(0.35)
                        .alignmentGuide(.top) { d in d[.top] }
                        .padding(.top, 10)
                }

                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(.red)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }

        private func useSmartBoost() {
            guard boosts.remaining > 0 else {
                errorText = "No Boosts left today."
                return
            }

            // Try placing first; only consume if it worked
            let success = game.applySmartBoost(movePenalty: 10)
            if success {
                _ = boosts.useOne()
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                dismiss()
            } else {
                errorText = "No safe placement found. Try a move first."
            }
        }
    }

    // MARK: - Daily Wallet Panel (buy boosts + coins)
    private struct DailyWalletPanel: View {
        @EnvironmentObject var levels: LevelsService
        @EnvironmentObject var boosts: BoostsService
        let dismiss: () -> Void

        @State private var showInsufficientCoins = false

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Label("Wallet", systemImage: "creditcard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                        Text("\(levels.coins)").font(.headline).monospacedDigit()
                    }
                    .softRaisedCapsule()
                }

                // Buy Boosts
                VStack(alignment: .leading, spacing: 8) {
                    Text("Buy Boosts").font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        walletBoostPill(icon: "wand.and.stars", title: "Reveal ×1",  cost: 5)  { buyReveal(cost: 5,  count: 1) }
                        walletBoostPill(icon: "wand.and.stars", title: "Reveal ×3",  cost: 12) { buyReveal(cost: 12, count: 3) }
                        walletBoostPill(icon: "wand.and.stars", title: "Reveal ×10", cost: 35) { buyReveal(cost: 35, count: 10) }
                    }
                }

                // Get Coins (IAP stubs)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Get Coins").font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        walletIAPPill(amount: 100,  price: "$0.99") { addCoins(100) }
                        walletIAPPill(amount: 300,  price: "$2.99") { addCoins(300) }
                        walletIAPPill(amount: 1200, price: "$7.99") { addCoins(1200) }
                    }
                }
            }
            .alert("Not enough coins", isPresented: $showInsufficientCoins) {
                Button("OK", role: .cancel) { }
            } message: { Text("You don't have enough coins for that purchase.") }
        }

        // Actions
        private func buyReveal(cost: Int, count: Int) {
            if levels.coins >= cost {
                levels.addCoins(-cost)
                boosts.grant(count: count)
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                dismiss()
            } else {
                showInsufficientCoins = true
            }
        }
        private func addCoins(_ n: Int) {
            levels.addCoins(n)
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            dismiss()
        }

        // Tiny pills (local copies)
        @ViewBuilder
        private func walletBoostPill(icon: String, title: String, cost: Int, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                VStack(spacing: 6) {
                    Image(systemName: icon).font(.headline)
                    Text(title).font(.caption).lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill").imageScale(.small)
                        Text("\(cost)").font(.caption2).monospacedDigit()
                    }.opacity(0.9)
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }

        @ViewBuilder
        private func walletIAPPill(amount: Int, price: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill").imageScale(.small)
                        Text("+\(amount)").font(.caption).monospacedDigit()
                    }
                    Text(price).font(.caption2).opacity(0.9)
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Small tile used in Boosts panel
    private struct BoostTile: View {
        let icon: String
        let title: String
        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 12).padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            )
        }
    }

    
    // MARK: - Header / Footer

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Text("Moves: \(game.moveCount)").bold()
                Text("Streak: \(game.streak)")
            }
        }
    }

    // MARK: - Shared region (Bag <-> Boosts) with horizontal slide
    @ViewBuilder
    private var underBoardRegion: some View {
        GeometryReader { regionGeo in
            let W = regionGeo.size.width
            ZStack(alignment: .bottomTrailing) {
                HStack(spacing: 0) {
                    // Letters (bag)
                    tileBag
                        .frame(width: W)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear  { bagHeight = geo.size.height }
                                    .onChange(of: geo.size) { oldSize, newSize in
                                        bagHeight = newSize.height
                                    }
//                                    // Keep bagRect accurate only when bag is visible
//                                    .onChange(of: showBoostsPanel) { _, isShowing in
//                                        bagRect = isShowing ? .zero : geo.frame(in: .named("stage"))
//                                    }

                            }
                        )

                }
//                .offset(x: showBoostsPanel ? -W : 0)                 // 👈 horizontal slide
//                .animation(.easeInOut(duration: 0.25), value: showBoostsPanel)
//                .clipped()

                // Optional: share button floats inside the same region
                if game.solved {
                    Button("Copy Share Text") {
                        UIPasteboard.general.string = game.shareString()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(12)
                }
            }
        }
        // Keep a stable height so bag/panel occupy identical vertical space
        .frame(height: max(bagHeight, boostsHeight))
    }


    // Reusable tile view (top-aligned content inside a fixed 72×72)
    @ViewBuilder
    private func boostTile(icon: String, title: String, material: Material) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2)
            Text(title).font(.caption)
        }
        .frame(width: 72, height: 72)
        .background(material)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alignmentGuide(.top) { d in d[.top] }           // 👈 report our own top
    }

    // MARK: - Board (responsive, instant drag)

    private var boardView: some View {
        GeometryReader { geo in
            let gap  = boardGap
            let span = min(geo.size.width, geo.size.height)
            let base = floor((span - 3 * gap) / 4)              // natural responsive cell
            let cell = max(36, min(base * tileScale, 120))      // clamp to a sensible range
            let boardSize = (4 * cell) + (3 * gap)

            ZStack(alignment: .topLeading) {
                boardGrid(cell: cell, gap: gap, boardSize: boardSize)
            }
            .frame(width: boardSize, height: boardSize, alignment: .topLeading)
            
            // publish live layout info for snapping & conversion
            .onAppear {
                currentBoardCell     = cell
                boardGap             = gap
                boardOriginInStage   = geo.frame(in: .named("stage")).origin
                boardRect            = geo.frame(in: .named("stage"))          // 👈 capture full rect
            }
            .onChange(of: geo.size) {
                currentBoardCell     = cell
                boardGap             = gap
                boardOriginInStage   = geo.frame(in: .named("stage")).origin
                boardRect            = geo.frame(in: .named("stage"))          // 👈 keep updated
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tile bag

    private var tileBag: some View {
        let bagTiles = game.tiles.filter { $0.location == .bag }
        let columns  = [GridItem(.adaptive(minimum: bagTileSize), spacing: bagGap)]

        // Compute reserved height from measured width so the grid doesn't shrink
        let width = max(1, bagGridWidth)
        let cols = max(1, Int(floor((width + bagGap) / (bagTileSize + bagGap))))
        let totalTiles = game.tiles.count                 // full capacity (usually 16)
        let fullRows = Int(ceil(Double(totalTiles) / Double(cols)))
        let reservedHeight = (CGFloat(fullRows) * bagTileSize)
                           + (CGFloat(max(0, fullRows - 1)) * bagGap)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Letter Bag")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: bagGap) {
                ForEach(bagTiles) { tile in
                    GeometryReader { bagGeo in
                        let origin = bagGeo.frame(in: .named("stage")).origin

                        tileView(
                            tile,
                            cell: bagTileSize,
                            gap: boardGap,
                            toStage: { pt in CGPoint(x: origin.x + pt.x, y: origin.y + pt.y) },
                            onDragBegan: {
                                ghostSize = .init(width: bagTileSize, height: bagTileSize)
                            },
                            onDragEnded: { stagePoint in
                                handleDrop(of: tile, at: stagePoint)   // drop anywhere in the grid
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedTileID == tile.id ? Color.accentColor : .clear,
                                    lineWidth: 2
                                )
                        )
                        .onTapGesture {
                            selectedTileID = (selectedTileID == tile.id) ? nil : tile.id
                        }
                    }
                    .frame(width: bagTileSize, height: bagTileSize)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            // Lock height only after width is measured
            .frame(height: (bagGridWidth > 0) ? reservedHeight : nil, alignment: .top)
            // Empty state overlay (centered vertically in the reserved area)
            .overlay(
                Group {
                    if bagTiles.isEmpty {
                        Text("Letter bag empty")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .allowsHitTesting(false)   // don’t block drops
                            .transition(.opacity)
                    }
                },
                alignment: .center
            )
            // Measure width + keep drag/drop hit area aligned to the whole grid
            .background(
                GeometryReader { gridGeo in
                    Color.clear
                        .onAppear {
                            bagGridWidth = gridGeo.size.width
                            bagRect = gridGeo.frame(in: .named("stage"))
                        }
                        .onChange(of: gridGeo.size) { _, newSize in
                            bagGridWidth = newSize.width
                            bagRect = gridGeo.frame(in: .named("stage"))
                        }
                        .onChange(of: showBoostsPanel) { _, isShowing in
                            bagRect = isShowing ? .zero : gridGeo.frame(in: .named("stage"))
                        }
                }
            )
        }
    }
    
    @ViewBuilder
    private func boardGrid(cell: CGFloat, gap: CGFloat, boardSize: CGFloat) -> some View {
        VStack(spacing: gap) {
            ForEach(0..<4, id: \.self) { (r: Int) in
                HStack(spacing: gap) {
                    ForEach(0..<4, id: \.self) { (c: Int) in
                        let coord = BoardCoord(row: r, col: c)
                        boardSquare(coord: coord, cell: cell, gap: gap)
                    }
                }
            }
        }
        .frame(width: boardSize, height: boardSize)
    }

    @ViewBuilder
    private func boardSquare(coord: BoardCoord, cell: CGFloat, gap: CGFloat) -> some View {
        GeometryReader { cellGeo in
            let origin = cellGeo.frame(in: .named("stage")).origin

            ZStack {
                // background cell
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .softRaised(corner: 12)   // 👈 subtle beveled tile well


                if let tile = game.tile(at: coord) {
                    tileView(
                        tile,
                        cell: cell,
                        gap: gap,
                        toStage: { pt in CGPoint(x: origin.x + pt.x, y: origin.y + pt.y) },
                        onDragBegan: {
                            ghostSize = .init(width: cell, height: cell)
                        },
                        onDragEnded: { stagePoint in
                            handleDrop(of: tile, at: stagePoint)   // 👈 handle drop on board or bag
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill cell
                } else {
                    Color.clear
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if game.solved { selectedTileID = nil; return }
                if let tid = selectedTileID,
                   let t = game.tiles.first(where: { $0.id == tid }) {
                    game.placeTile(t, at: coord)
                    selectedTileID = nil
                }
            }
        }
        .frame(width: cell, height: cell)
    }

    // MARK: - Tile view with instant drag

    @ViewBuilder
    private func tileView(
        _ tile: LetterTile,
        cell: CGFloat,
        gap: CGFloat,
        toStage: @escaping (CGPoint) -> CGPoint,
        onDragBegan: @escaping () -> Void,
        onDragEnded: ((CGPoint) -> Void)? = nil
    ) -> some View {
        // Status flags
        let isOnBoard: Bool = {
            if case .board = tile.location { return true } else { return false }
        }()
        let lockedByBoost = game.boostedLockedTileIDs.contains(tile.id)
        let lockedByWorld = game.worldLockedTileIDs.contains(tile.id)
        let solved        = game.solved
        let lockedOnBoard = (lockedByBoost || lockedByWorld || solved) && isOnBoard

        // Shape fill as a ShapeStyle (not a View)
        let tileFillStyle: AnyShapeStyle = {
            if lockedByWorld && isOnBoard {
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.95), Color.purple],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            } else if (lockedByBoost || solved) && isOnBoard {
                return AnyShapeStyle(Color.green)
            } else {
                return AnyShapeStyle(Color(.systemBackground))
            }
        }()

        let strokeColor: Color = {
            if lockedByWorld && isOnBoard { return .white.opacity(0.85) }
            if (lockedByBoost || solved) && isOnBoard { return .green.opacity(0.85) }
            return .secondary
        }()

        let textColor: Color = {
            if (lockedByWorld && isOnBoard) || ((lockedByBoost || solved) && isOnBoard) { return .white }
            return .primary
        }()

        let side = max(1, cell - 4)
        let corner: CGFloat = 8

        ZStack {
            // Base tile
            RoundedRectangle(cornerRadius: corner).fill(tileFillStyle)
            RoundedRectangle(cornerRadius: corner).stroke(strokeColor, lineWidth: 1)

            // Letter
            Text(String(tile.letter).uppercased())
                .font(.title3).bold()
                .foregroundStyle(textColor)

            // 2s SHIMMER ON PURPLE-LOCKED TILES
            if game.worldShimmerIDs.contains(tile.id) {
                ShimmerOverlay(
                    duration: 1.5,
                    bandScale: 1.4,  // width
                    minBand: 10,
                    thickness: 24,   // height
                    angleDeg: 0,
                    peakOpacity: 0.45,
                    overscan: 60
                )
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .frame(width: side, height: side)
        .shadow(radius: 1, x: 0, y: 1)

        // Block dragging for any locked-on-board tile
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !lockedOnBoard else { return }
                    draggingTileID = tile.id
                    dragPoint = toStage(value.location)
                    onDragBegan()
                }
                .onEnded { value in
                    guard !lockedOnBoard else { return }
                    draggingTileID = nil
                    onDragEnded?(toStage(value.location))
                }
        )
    }



    // Diagonal sheen that sweeps once over `duration` seconds
    private struct ShimmerOverlay: View {
        var duration: Double = 2.0

        // existing knobs
        var bandScale: CGFloat = 1.2     // width as a multiple of tile width
        var minBand:   CGFloat = 10
        var thickness: CGFloat = 24      // still used (adds on top)
        var angleDeg:  Double  = 24
        var peakOpacity: Double = 0.45

        // NEW: extra padding on top of the computed minimum
        var overscan: CGFloat = 24

        @State private var run = false

        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let band = max(minBand, w * bandScale)

                // Height required to cover the tile when the band is rotated by angleDeg:
                // hNeeded = |w*sinθ| + |h*cosθ|  (bounding box of a rotated rect)
                let θ = CGFloat(angleDeg) * .pi / 180
                let coverHeight = abs(w * sin(θ)) + abs(h * cos(θ))

                // Add some headroom so you never see the top/bottom edge
                let neededHeight = coverHeight + band * 0.25 + thickness + overscan

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.0), .white.opacity(peakOpacity), .white.opacity(0.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: band, height: neededHeight)
                    .rotationEffect(.degrees(angleDeg))
                    .offset(x: run ? w + band : -band)
                    .onAppear { withAnimation(.linear(duration: duration)) { run = true } }
            }
        }
    }

    private enum TraceAxis { case horizontal, vertical }

    private struct LineTracer: View {
        var direction: TraceAxis
        var tint: Color = .white
        var duration: Double = 0.45
        var lineWidth: CGFloat = 6
        var tailDots: Int = 5
        var tailSpacing: CGFloat = 0.12
        var wobble: CGFloat = 1.5

        @State private var phase: CGFloat = 0   // 0 → 1 across the tile

        var body: some View {
            GeometryReader { geo in
                TracerCanvas(
                    direction: direction,
                    tint: tint,
                    lineWidth: lineWidth,
                    tailDots: tailDots,
                    tailSpacing: tailSpacing,
                    wobble: wobble,
                    phase: phase
                )
                .onAppear {
                    phase = 0
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            }
        }
    }

    private struct TracerCanvas: View {
        var direction: TraceAxis
        var tint: Color
        var lineWidth: CGFloat
        var tailDots: Int
        var tailSpacing: CGFloat
        var wobble: CGFloat
        var phase: CGFloat

        var body: some View {
            Canvas { ctx, size in
                var ctx = ctx // allow passing as inout to helpers
                let span = spanLength(size)
                guard span > 0 else { return }

                let pos = phase * span
                let bar = coreBarRect(size: size, pos: pos)

                drawCoreBar(ctx: &ctx, bar: bar)
                drawTail(ctx: &ctx, size: size, pos: pos, span: span)
            }
        }

        // MARK: - Helpers (small, explicit → fast type-check)

        private func spanLength(_ size: CGSize) -> CGFloat {
            direction == .horizontal ? size.width : size.height
        }

        private func coreBarRect(size: CGSize, pos: CGFloat) -> CGRect {
            if direction == .horizontal {
                return CGRect(x: pos - lineWidth/2, y: 0, width: lineWidth, height: size.height)
            } else {
                return CGRect(x: 0, y: pos - lineWidth/2, width: size.width, height: lineWidth)
            }
        }

        private func coreGradient(for rect: CGRect) -> GraphicsContext.Shading {
            let grad = Gradient(colors: [tint.opacity(0.0), tint.opacity(0.85), tint.opacity(0.0)])
            if direction == .horizontal {
                return .linearGradient(
                    grad,
                    startPoint: CGPoint(x: rect.minX, y: 0),
                    endPoint:   CGPoint(x: rect.maxX, y: 0)
                )
            } else {
                return .linearGradient(
                    grad,
                    startPoint: CGPoint(x: 0, y: rect.minY),
                    endPoint:   CGPoint(x: 0, y: rect.maxY)
                )
            }
        }

        private func drawCoreBar(ctx: inout GraphicsContext, bar: CGRect) {
            ctx.fill(Path(bar), with: coreGradient(for: bar))
        }

        private func tailDot(at k: Int, pos: CGFloat, span: CGFloat, size: CGSize) -> (CGRect, Double) {
            let back = CGFloat(k) * tailSpacing * span
            let alpha = max(0, 1 - CGFloat(k) * 0.22)

            // gentle perpendicular wobble
            let angle = Double((pos - back) / max(1, span)) * 2.0 * .pi
            let wob = CGFloat(sin(angle)) * wobble

            let r: CGFloat = 2.0 * max(0.6, alpha)

            if direction == .horizontal {
                let x = pos - back
                let y = size.height * 0.5 + wob
                return (CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2), Double(alpha) * 0.9)
            } else {
                let x = size.width * 0.5 + wob
                let y = pos - back
                return (CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2), Double(alpha) * 0.9)
            }
        }

        private func drawTail(ctx: inout GraphicsContext, size: CGSize, pos: CGFloat, span: CGFloat) {
            guard tailDots > 0 else { return }
            for k in 1...tailDots {
                let (rect, a) = tailDot(at: k, pos: pos, span: span, size: size)
                ctx.opacity = a
                ctx.fill(Path(ellipseIn: rect), with: .color(tint))
            }
        }
    }



    // Soft purple glow for the trace pass
    private struct TraceGlow: View {
        var body: some View {
            ZStack {
                // Outer bloom
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.18))
                    .blur(radius: 8)

                // Inner edge highlight
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .blur(radius: 0.5)
            }
        }
    }

    // Small sparkle burst used during the trace pass
    private struct SparkleBurst: View {
        var tint: Color = .white
        var body: some View {
            TimelineView(.periodic(from: Date(), by: 1.0 / 60.0)) { tl in
                let tAbs = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    let cx = size.width / 2, cy = size.height / 2
                    let count = 10
                    let lifetime: Double = 0.6

                    for i in 0..<count {
                        let stagger = Double(i) * 0.025
                        let t = max(0, min(1, (tAbs - stagger).truncatingRemainder(dividingBy: lifetime) / lifetime))
                        let theta = Double(i) * (.pi * 2) / Double(count)
                        let r = CGFloat(t) * (min(size.width, size.height) * 0.45)
                        let x = cx + CGFloat(cos(theta)) * r
                        let y = cy + CGFloat(sin(theta)) * r
                        let alpha = (1 - t) * 0.9

                        ctx.opacity = alpha
                        let dotR: CGFloat = 1.6
                        let rect = CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(tint))
                    }
                }
            }
        }
    }



    @ViewBuilder
    private func tileGhost(_ tile: LetterTile, size: CGSize) -> some View {
        let side = min(size.width, size.height)
        let corner: CGFloat = 8
        let fontSize = side * 0.55   // scale letter with tile size

        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(Color(.systemBackground).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .stroke(Color.accentColor, lineWidth: 2)
                )
            Text(String(tile.letter).uppercased())
                .font(.system(size: fontSize, weight: .bold))
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .shadow(radius: 4)
    }

    // MARK: - Drag/drop helpers

    private func handleDrop(of tile: LetterTile, at stagePoint: CGPoint) {
        // 1) Try snapping to the 4×4 board first
        let localPoint = CGPoint(
            x: stagePoint.x - boardRect.minX,
            y: stagePoint.y - boardRect.minY
        )
        if let coord = coordFrom(
            pointInBoard: localPoint,
            cell: currentBoardCell,
            gap: boardGap
        ) {
            game.placeTile(tile, at: coord)
            return
        }

        // 2) Otherwise, if it's inside (or near) the LazyVGrid, return to bag
        //    bagRect should be the LazyVGrid frame captured in stage space.
        let hitRect = bagRect.insetBy(dx: -12, dy: -12)  // gentle expansion
        if hitRect.contains(stagePoint) {
            if case .board(let prev) = tile.location {
                game.removeTile(from: prev)
            }
            return
        }

        // 3) Else: no change (tile stays where it was)
    }


    private func coordFromStage(_ stagePoint: CGPoint) -> BoardCoord? {
        // Convert from the shared "stage" space to the board’s local space
        let local = CGPoint(x: stagePoint.x - boardRect.minX,
                            y: stagePoint.y - boardRect.minY)
        return coordFrom(pointInBoard: local,
                         cell: currentBoardCell,
                         gap: boardGap)
    }

    // MARK: - Point → cell mapping

    private func coordFrom(pointInBoard p: CGPoint, cell: CGFloat, gap: CGFloat) -> BoardCoord? {
        let span = (4 * cell) + (3 * gap)
        guard p.x >= 0, p.y >= 0, p.x <= span, p.y <= span else { return nil }

        func index(for v: CGFloat) -> Int? {
            var rem = v
            for i in 0..<4 {
                if rem <= cell { return i }
                rem -= cell
                if i < 3 {
                    if rem <= gap { return nil }   // ended in the gap → ignore drop
                    rem -= gap
                }
            }
            return nil
        }

        guard let col = index(for: p.x), let row = index(for: p.y) else { return nil }
        return BoardCoord(row: row, col: col)
    }
}
