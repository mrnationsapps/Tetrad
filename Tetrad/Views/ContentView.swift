import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

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

    // TESTING ONLY.  DO NOT LEAVE ON RELEASE
    @State private var boardTest: Int = 0          // adjust to shift the daily puzzle. testing purposes only
    @State private var boostTest: Int = 10
    
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
                underBoardControls           // 👈 Boosts button moved here
                tileArea                     // 👈 shows Tile Bag OR compact Boosts panel
                footer
            }
            .padding()

            if let id = draggingTileID,
               let tile = game.tiles.first(where: { $0.id == id }) {
                tileGhost(tile, size: ghostSize)
                    .frame(width: ghostSize.width, height: ghostSize.height)
                    .position(dragPoint)      // point is in "stage"
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "stage")       // shared space for board + bag + ghost
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
    }

    // MARK: - Header / Footer

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.title3)
                }
                Spacer()
                Text("Moves: \(game.moveCount)").bold()
                Spacer()
                Text("Streak: \(game.streak)")
            }

            HStack {
                Text("TETRAD")
                    .font(.title).bold()
                Spacer()
                // (Boosts button now lives under the board)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            if game.solved {
                Button("Copy Share Text") {
                    UIPasteboard.general.string = game.shareString()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }


    // MARK: - Under-board controls
    private var underBoardControls: some View {
        HStack {
            Spacer()
            Button {
                // Toggle compact Boosts panel (no targeting state anymore)
                showBoostsPanel.toggle()
            } label: {
                Label("Boosts", systemImage: "bolt.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
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

    private var compactBoostsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Boosts", systemImage: "bolt.fill").font(.headline)
                Spacer()
                Text("\(effectiveBoostsRemaining) left today")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                // Smart Boost
                Button {
                    let success = game.applySmartBoost(movePenalty: 10)
                    if success {
                        if boostTest > 0 {
                            boostTest -= 1            // burn a test boost first
                        } else {
                            _ = boosts.useOne()       // then fall back to real pool
                        }
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "wand.and.stars").font(.title2)
                        Text("Smart").font(.caption)
                    }
                    .frame(width: 72, height: 72)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canUseBoost)   // uses the combined pool


                // Placeholders for future boosts
                VStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right").font(.title2)
                    Text("Swap").font(.caption)
                }
                .frame(width: 72, height: 72)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(0.35)

                VStack(spacing: 6) {
                    Image(systemName: "eye").font(.title2)
                    Text("Clarity").font(.caption)
                }
                .frame(width: 72, height: 72)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(0.35)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear { bagRect = .zero } // while panel is open, disable bag hit-tests
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
                                handleDrop(of: tile, at: stagePoint)   // 👈 allows dragging back into bag
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
        }
        // Capture the bag's live frame in the shared "stage" coordinate space
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear  { bagRect = geo.frame(in: .named("stage")) }
                    .onChange(of: geo.size) { _ in
                        bagRect = geo.frame(in: .named("stage"))
                    }
            }
        )
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary, lineWidth: 1)
                    )

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
                // Normal tap-to-place only
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
        Text(String(tile.letter).uppercased())
            .font(.title3).bold()
            .frame(width: max(1, cell - 4), height: max(1, cell - 4))
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary, lineWidth: 1)
            )
            .cornerRadius(8)
            .shadow(radius: 1, x: 0, y: 1)
            // Instant drag (no long press)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        draggingTileID = tile.id
                        dragPoint = toStage(value.location)   // convert to "stage"
                        onDragBegan()
                    }
                    .onEnded { value in
                        draggingTileID = nil
                        let stagePoint = toStage(value.location)
                        onDragEnded?(stagePoint)               // notify caller
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
        // Convert from stage-space to board-local
        let localPoint = CGPoint(
            x: stagePoint.x - boardRect.minX,
            y: stagePoint.y - boardRect.minY
        )

        // If the drop lands inside the 4×4 board, snap to that cell
        if let coord = coordFrom(
            pointInBoard: localPoint,
            cell: currentBoardCell,
            gap: boardGap
        ) {
            game.placeTile(tile, at: coord)
            return
        }

        // If the drop lands inside the bag area, send the tile back to the bag
        if bagRect.contains(stagePoint) {
            if case .board(let prev) = tile.location {
                game.removeTile(from: prev)
            }
            return
        }

        // Otherwise: do nothing (tile stays wherever it was before the drag)
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
