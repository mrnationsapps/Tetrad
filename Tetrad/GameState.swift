import Foundation
import SwiftUI

final class GameState: ObservableObject {
    @Published var tiles: [LetterTile] = []
    @Published var board: [[UUID?]] = Array(repeating: Array(repeating: nil, count: 4), count: 4)
    @Published var solved: Bool = false
    @Published var invalidHighlights: Set<Int> = [] // indices 0..7 for rows/cols if needed

    @Published var moveCount: Int = 0
    @Published var streak: Int = UserDefaults.standard.integer(forKey: "tetrad_streak")
    @Published var lastSolvedDateUTC: String? = UserDefaults.standard.string(forKey: "tetrad_lastSolvedUTC")

    private let versionKey = "TETRAD_v1"
    private var identity: PuzzleIdentity?

    init() {
        bootstrapForToday()
    }

    // MARK: - Daily bootstrap / generation / restore

    func bootstrapForToday(date: Date = Date()) {
        let todayKey = currentUTCDateKey(date)

        if let id = Persistence.loadIdentity(), id.dayUTC == todayKey {
            identity = id
            buildTiles(from: id.bag)
            restoreRunStateOrStartFresh(for: todayKey)
        } else {
            Persistence.clearForNewDay()
            generateNewDailyIdentity(date: date)
            resetForNewIdentity(todayKey: todayKey)
            persistProgressSnapshot()
        }
    }

    private func generateNewDailyIdentity(date: Date) {
        let words = DictionaryLoader.loadFourLetterWords()
        let gen = WordSquareGenerator(words: words)
        var rng: any RandomNumberGenerator = SeededRNG.dailySeed(version: versionKey, date: date)

        if let puzzle = gen.generateDaily(rng: &rng) {
            let bag = String(puzzle.letters.map { Character($0.lowercased()) })
            identity = PuzzleIdentity(dayUTC: currentUTCDateKey(date), bag: bag)
        } else {
            let fallback = Array("tetradwordpuzzlega".prefix(16))
            identity = PuzzleIdentity(dayUTC: currentUTCDateKey(date), bag: String(fallback))
        }
        if let id = identity { Persistence.saveIdentity(id) }
        if let id = identity { buildTiles(from: id.bag) }
    }

    private func buildTiles(from bag: String) {
        tiles = bag.map { LetterTile(letter: $0) }
        board = Array(repeating: Array(repeating: nil, count: 4), count: 4)
        solved = false
        invalidHighlights = []
    }

    private func restoreRunStateOrStartFresh(for todayKey: String) {
        if let run = Persistence.loadRunState(), run.lastPlayedDayUTC == todayKey {
            moveCount = run.moves
            solved = run.solvedToday
            streak = run.streak

            // Clear board & reset tiles to bag
            board = Array(repeating: Array(repeating: nil, count: 4), count: 4)
            for i in tiles.indices {
                var t = tiles[i]
                t.location = .bag
                t.hasBeenPlacedOnce = false
                tiles[i] = t
            }
            // Re-apply placements (consume letters from bag to handle duplicates)
            for p in run.placements {
                if let idx = tiles.firstIndex(where: { $0.letter == p.letter && $0.location == .bag }) {
                    var t = tiles[idx]
                    t.hasBeenPlacedOnce = true
                    let bc = BoardCoord(row: p.row, col: p.col)
                    t.location = .board(bc)
                    tiles[idx] = t
                    board[p.row][p.col] = t.id
                }
            }

        } else {
            resetForNewIdentity(todayKey: todayKey)
        }
    }

    private func resetForNewIdentity(todayKey: String) {
        moveCount = 0
        solved = false
        board = Array(repeating: Array(repeating: nil, count: 4), count: 4)
        let run = RunState(moves: 0,
                           solvedToday: false,
                           placements: [],
                           streak: streak,
                           lastPlayedDayUTC: todayKey)
        Persistence.saveRunState(run)
    }

    // MARK: - Existing APIs

    func newDailyPuzzle(date: Date = Date()) {
        // 🔎 Probe the bundled dictionary so you can see the count in Xcode’s console
        let dict = DictionaryLoader.loadFourLetterWords()
        NSLog("📚 Tetrad dictionary loaded: \(dict.count) words")

        // 👇 your existing orchestration
        Persistence.clearForNewDay()
        generateNewDailyIdentity(date: date)
        resetForNewIdentity(todayKey: currentUTCDateKey(date))
        persistProgressSnapshot()
    }


    func tile(at coord: BoardCoord) -> LetterTile? {
        guard let id = board[coord.row][coord.col] else { return nil }
        return tiles.first(where: { $0.id == id })
    }

    func placeTile(_ tile: LetterTile, at coord: BoardCoord) {
        var t = tile
        var isMove = false

        switch t.location {
        case .bag:
            isMove = t.hasBeenPlacedOnce
            t.hasBeenPlacedOnce = true
        case .board(let prev):
            if prev != coord {
                isMove = true
                board[prev.row][prev.col] = nil
            }
        }

        if let occupying = self.tile(at: coord) {
            if case .board(let prev) = tile.location {
                moveTileTo(occupying, to: .board(prev), countAsMove: false)
                } else {
                moveTileTo(occupying, to: .bag, countAsMove: false)
            }
        }

        t.location = .board(coord)
        if let idx = tiles.firstIndex(where: { $0.id == t.id }) {
            tiles[idx] = t
        }
        board[coord.row][coord.col] = t.id

        if isMove { moveCount += 1 }
        checkIfSolved()
        persistProgressSnapshot()
    }

    func removeTile(from coord: BoardCoord) {
        guard let id = board[coord.row][coord.col],
              let idx = tiles.firstIndex(where: { $0.id == id }) else { return }
        var t = tiles[idx]
        t.location = .bag
        tiles[idx] = t
        board[coord.row][coord.col] = nil
        persistProgressSnapshot()
    }

    private func moveTileTo(_ tile: LetterTile, to dest: TileLocation, countAsMove: Bool) {
        var t = tile
        if case .board(let prev) = t.location {
            board[prev.row][prev.col] = nil
        }
        t.location = dest
        if case .board(let c) = dest {
            board[c.row][c.col] = t.id
        }
        if let idx = tiles.firstIndex(where: { $0.id == t.id }) {
            tiles[idx] = t
        }
        if countAsMove { moveCount += 1 }
    }

    func shareString(date: Date = Date()) -> String {
        let utc = ISO8601DateFormatter()
        utc.timeZone = TimeZone(secondsFromGMT: 0)
        utc.formatOptions = [.withFullDate]
        let d = utc.string(from: date)
        var lines: [String] = []
        lines.append("Tetrad " + d)
        lines.append("✅ Solved in \(moveCount) moves")
        if streak > 0 { lines.append("🔥 \(streak)-day streak") }
        return lines.joined(separator: "\n")
    }

    private func checkIfSolved() {
        // TEMP: consider filled board solved; replace with trie validation later
        for r in 0..<4 {
            for c in 0..<4 {
                if board[r][c] == nil { return }
            }
        }
        solved = true
        advanceStreakIfNeeded()
        registerSolvedAndPersist()
    }

    private func advanceStreakIfNeeded() {
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = .init(secondsFromGMT: 0)
        fmt.formatOptions = [.withFullDate]
        let today = fmt.string(from: Date())

        if lastSolvedDateUTC == today { return }
        if let last = lastSolvedDateUTC {
            if let yester = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: fmt.date(from: today)!) {
                let ystr = fmt.string(from: yester)
                streak = (last == ystr) ? (streak + 1) : 1
            } else {
                streak = 1
            }
        } else {
            streak = 1
        }
        lastSolvedDateUTC = today
        UserDefaults.standard.set(streak, forKey: "tetrad_streak")
        UserDefaults.standard.set(lastSolvedDateUTC, forKey: "tetrad_lastSolvedUTC")
    }

    // MARK: - Persistence snapshots

    private func persistProgressSnapshot() {
        guard let id = identity else { return }
        var placements: [TilePlacement] = []
        for r in 0..<4 {
            for c in 0..<4 {
                if let tile = tile(at: BoardCoord(row: r, col: c)) {
                    placements.append(TilePlacement(row: r, col: c, letter: tile.letter))
                }
            }
        }
        let run = RunState(moves: moveCount,
                           solvedToday: solved,
                           placements: placements,
                           streak: streak,
                           lastPlayedDayUTC: id.dayUTC)
        Persistence.saveIdentity(id)
        Persistence.saveRunState(run)
    }

    private func registerSolvedAndPersist() {
        guard let id = identity else { return }
        if var run = Persistence.loadRunState() {
            if !run.solvedToday {
                run.solvedToday = true
                run.moves = moveCount
                run.streak = streak
                run.lastPlayedDayUTC = id.dayUTC
                Persistence.saveRunState(run)
            }
        }
        persistProgressSnapshot()
    }
}
