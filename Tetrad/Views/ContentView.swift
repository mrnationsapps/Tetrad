import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    // TESTING ONLY.  DO NOT LEAVE ON RELEASE
    @State private var boardTest: Int = 7          // shifts day away from today
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
                underBoardRegion   // (replaces previous tileArea/footer)
                underBoardControls           // 👈 Boosts button moved here
                //footer
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
            
            if showWinPopup {
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
                    .offset(x: -20)   // nudge 5pt to the left

            }
        }

        .onAppear {
            let offsetDate = Calendar(identifier: .gregorian).date(
                byAdding: .day, value: boardTest, to: Date()
            ) ?? Date()
            game.bootstrapForToday(date: offsetDate)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let offsetDate = Calendar(identifier: .gregorian).date(
                    byAdding: .day, value: boardTest, to: Date()
                ) ?? Date()
                game.bootstrapForToday(date: offsetDate)
            }
        }
        
        .onChange(of: game.solved) { _, isSolved in
            if isSolved { withAnimation(.spring()) { showWinPopup = true } }
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

//    private var footer: some View {
//        HStack {
//            Spacer()
//            if game.solved {
//                Button("Copy Share Text") {
//                    UIPasteboard.general.string = game.shareString()
//                }
//                .buttonStyle(.borderedProminent)
//            }
//        }
//    }

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
                                    // Keep bagRect accurate only when bag is visible
                                    .onChange(of: showBoostsPanel) { _, isShowing in
                                        bagRect = isShowing ? .zero : geo.frame(in: .named("stage"))
                                    }

                            }
                        )

                    // Boosts panel
                    compactBoostsPanel
                        .frame(width: W)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear  { boostsHeight = geo.size.height }
                                    .onChange(of: geo.size) { _, newSize in
                                        boostsHeight = newSize.height
                                    }
                            }
                        )
                }
                .offset(x: showBoostsPanel ? -W : 0)                 // 👈 horizontal slide
                .animation(.easeInOut(duration: 0.25), value: showBoostsPanel)
                .clipped()

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

    // MARK: - Under-board controls
    private var underBoardControls: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showBoostsPanel.toggle()
                }
                // When the boosts panel is showing, disable bag hit-tests
                if showBoostsPanel { bagRect = .zero }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showBoostsPanel ? "chevron.right" : "chevron.left")
                        .imageScale(.medium)
                    Text(showBoostsPanel ? "Letters" : "Boosts")
                }
                .foregroundStyle(.primary) // good contrast on soft surface
            }
            .buttonStyle(SoftRaisedPillStyle(height: 52))
        }

    }


    // MARK: - Tile Area (Bag or Compact Boosts Panel)

    @ViewBuilder
    private var tileArea: some View {
        if showBoostsPanel {
            compactBoostsPanel
        } else {
            tileBag
        }
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

    private var compactBoostsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .top) {
                Label("Boosts", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(effectiveBoostsRemaining) left today")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Tiles row
            HStack(alignment: .top, spacing: 12) {
                // BOOST: REVEAL (Button)
                Button {
                    let success = game.applySmartBoost(movePenalty: 10)
                    if success {
                        if boostTest > 0 { boostTest -= 1 } else { _ = boosts.useOne() }
                    }
                } label: {
                    boostTile(icon: "wand.and.stars", title: "Reveal", material: .ultraThinMaterial)
                }
                .buttonStyle(.plain)
                .disabled(!canUseBoost)
                .alignmentGuide(.top) { d in d[.top] }

                // Placeholders (same top guide)
                boostTile(icon: "arrow.left.arrow.right", title: "Swap", material: .thinMaterial)
                    .opacity(0.35)
                    .alignmentGuide(.top) { d in d[.top] }

                boostTile(icon: "eye", title: "Clarity", material: .thinMaterial)
                    .opacity(0.35)
                    .alignmentGuide(.top) { d in d[.top] }
                    .padding(.top, 10)
            }
        }
        // 👇 Pin the whole panel to the top of its slot (not just the header)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            // keep the grid a constant, top-aligned height (for the full bag)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: reservedHeight, alignment: .top)
            // measure width + keep drag/drop hit area aligned to the whole grid
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
        let isBoostLocked = game.boostedLockedTileIDs.contains(tile.id)
        let isOnBoard: Bool = { if case .board = tile.location { true } else { false } }()
        let lockedOnBoard = (isBoostLocked || game.solved) && isOnBoard
        let side = max(1, cell - 4)
        let isPressed = (draggingTileID == tile.id)

        ZStack {
            if lockedOnBoard {
                // Success/locked
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.85), lineWidth: 1)
                    )
            } else {
                // Soft Raised neutral tile
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .softRaised(corner: 12, pressed: isPressed)
            }

            Text(String(tile.letter).uppercased())
                .font(.title3).bold()
                .foregroundStyle(lockedOnBoard ? Color.white : Color.primary)
        }
        .frame(width: side, height: side)
        .shadow(radius: 1, x: 0, y: 1)

        // Disable drag for locked tiles; allow pressed effect while dragging
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
                    let stagePoint = toStage(value.location)
                    onDragEnded?(stagePoint)
                }
        )
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
