import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var bagGap: CGFloat = 0   // spacing between bag tiles
    @State private var boardTest: Int = 2   // adjust to shift the daily puzzle. testing purposes only


    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                header
                boardView
                tileBag
                footer
            }
            .padding()
            
            if let id = draggingTileID,
               let tile = game.tiles.first(where: { $0.id == id }) {
                tileGhost(tile, size: ghostSize)
                    .frame(width: ghostSize.width, height: ghostSize.height)  // 👈 size matches source
                    .position(dragPoint)                                      // point is in "stage"
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
        .onChange(of: scenePhase) { oldPhase, newPhase in
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
        HStack {
            Text("Tetrad").font(.largeTitle).bold()
            Spacer()
            VStack(alignment: .trailing) {
                Text("Moves: \(game.moveCount)").bold()
                Text("Streak: \(game.streak)")
            }.font(.subheadline)
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
                currentBoardCell  = cell
                boardGap   = gap
                boardOriginInStage = geo.frame(in: .named("stage")).origin
            }
            .onChange(of: geo.size) {
                currentBoardCell  = cell
                boardGap   = gap
                boardOriginInStage = geo.frame(in: .named("stage")).origin
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    // MARK: - Tile bag

    private var tileBag: some View {
        let bagTiles = game.tiles.filter { $0.location == .bag }
        let columns  = [GridItem(.adaptive(minimum: bagTileSize), spacing: bagGap)]

        return VStack(alignment: .leading, spacing: 8) {
                Text("Letter Bag").font(.headline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: bagGap) {   // 👈 use bagGap
                ForEach(bagTiles) { tile in
                    GeometryReader { bagGeo in
                        let origin = bagGeo.frame(in: .named("stage")).origin

                        tileView(
                            tile,
                            cell: bagTileSize,
                            gap: boardGap,   // gap here isn’t really used for bag snapping
                            toStage: { pt in CGPoint(x: origin.x + pt.x, y: origin.y + pt.y) },
                            onDragBegan: {
                                ghostSize = .init(width: bagTileSize, height: bagTileSize)
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
                        onDragBegan: { ghostSize = .init(width: cell, height: cell) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)   // ← fill cell
                } else {
                    Color.clear
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
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
        onDragBegan: @escaping () -> Void
    ) -> some View {
        let corner = max(6, cell * 0.12)
        let fontSz = max(14, cell * 0.55)

        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(Color(.systemBackground))
                // stroke *inside* the bounds so we don't need to inset the content
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(Color.secondary, lineWidth: 1)
                )

            Text(String(tile.letter).uppercased())
                .font(.system(size: fontSz, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        // ⬇️ No fixed 60×60 here — parent decides size
        .contentShape(Rectangle())
        .shadow(radius: 1, x: 0, y: 1)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onDragBegan()
                    draggingTileID = tile.id
                    dragPoint = toStage(value.location)
                }
                .onEnded { value in
                    draggingTileID = nil
                    let stagePoint = toStage(value.location)
                    let boardPoint = CGPoint(
                        x: stagePoint.x - boardOriginInStage.x,
                        y: stagePoint.y - boardOriginInStage.y
                    )
                    if let coord = coordFrom(pointInBoard: boardPoint, cell: currentBoardCell, gap: boardGap) {
                        game.placeTile(tile, at: coord)
                        selectedTileID = nil
                    }
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
                .font(.system(size: fontSize, weight: .bold, design: .default))
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .shadow(radius: 4)
    }


    // MARK: - Point → cell mapping (uses live cell/gap passed in)

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


