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
    @Published var isLevelMode: Bool = false


    // 🟩 Smart Boost locks (runtime + persisted-by-coord)
    @Published var boostedLockedTileIDs: Set<UUID> = []           // runtime-only (IDs change per session)
    private var boostedLockedCoords: Set<String> = []             // persisted as "r,c" strings

    private let versionKey = "TETRAD_v1"
    private var identity: PuzzleIdentity?
    private var lastSmartBoostCoord: BoardCoord? = nil

    // 🔹 In-memory cache of today's 4-word solution (rows), set during generation.
    //     Not persisted (we can always regenerate deterministically for today).
    private var solution: [String]? = nil

    init() {
        // Intentionally empty: we bootstrap when the user chooses to play
    }

    // MARK: - Daily bootstrap / generation / restore

    func bootstrapForToday(date: Date = Date()) {
        let todayKey = currentUTCDateKey(date)
        NSLog("bootstrapForToday → \(todayKey)")
        isLevelMode = false

        // 1) Always (re)compute today's identity deterministically from the UTC date.
        generateNewDailyIdentity(date: date)

        // 2) Build tiles from today's bag so the board reflects today's letters.
        if let id = identity {
            buildTiles(from: id.bag)
        } else {
            NSLog("⚠️ bootstrapForToday: identity missing after generation for \(todayKey)")
        }

        // 3) Restore saved progress for today if it exists; otherwise start fresh.
        restoreRunStateOrStartFresh(for: todayKey)

        // 4) Reload Smart Boost locks for today and map them to current tile IDs.
        loadBoostLocks(for: todayKey)
    }

    private func generateNewDailyIdentity(date: Date) {
        let words = DictionaryLoader.loadFourLetterWords()
        let gen = WordSquareGenerator(words: words)
        var rng: any RandomNumberGenerator = SeededRNG.dailySeed(version: versionKey, date: date)

        if let puzzle = gen.generateDaily(rng: &rng) {
            // Keep the row solution in memory for Boosts / validation
            self.solution = puzzle.solution
            let bag = String(puzzle.letters.map { Character($0.lowercased()) })
            identity = PuzzleIdentity(dayUTC: currentUTCDateKey(date), bag: bag)
        } else {
            self.solution = nil
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
        lastSmartBoostCoord = nil
        boostedLockedTileIDs = []
        boostedLockedCoords = []
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
        lastSmartBoostCoord = nil
        boostedLockedTileIDs = []
        boostedLockedCoords = []
        clearBoostLocks(for: todayKey) // clean slate for the day key
        let run = RunState(moves: 0,
                           solvedToday: false,
                           placements: [],
                           streak: streak,
                           lastPlayedDayUTC: todayKey)
        Persistence.saveRunState(run)
    }

    // MARK: - Existing APIs

    func newDailyPuzzle(date: Date = Date()) {
        NSLog("🟡 newDailyPuzzle() called for \(currentUTCDateKey(date))")

        // 🔎 Probe the bundled dictionary so you can see the count in Xcode’s console
        let dict = DictionaryLoader.loadFourLetterWords()
        NSLog("📚 Tetrad dictionary loaded: \(dict.count) words")

        // 👇 your existing orchestration
        if let id = identity { clearBoostLocks(for: id.dayUTC) }
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
        // 🚫 Do not allow moving a Smart-Boost-locked tile
        if boostedLockedTileIDs.contains(tile.id) { return }

        // 🚫 Do not allow displacing a Smart-Boost-locked occupant
        if let occ = self.tile(at: coord), boostedLockedTileIDs.contains(occ.id) { return }

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
        // 🚫 Can't remove Smart-Boost-locked tile
        if boostedLockedTileIDs.contains(id) { return }

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
        // Need today's solution to validate
        guard let solution = self.solution, solution.count == 4 else { return }

        // Board must be fully filled AND match the exact 4×4 solution letters
        for r in 0..<4 {
            for c in 0..<4 {
                // Must have a tile in every cell
                guard let id = board[r][c],
                      let tile = tiles.first(where: { $0.id == id }) else {
                    return
                }
                let correctChar = Array(solution[r])[c]
                if tile.letter != correctChar {
                    return // any mismatch → not solved
                }
            }
        }

        // All 16 matched
        solved = true

        // Only Daily mode updates streak & daily persistence
        if !isLevelMode {
            advanceStreakIfNeeded()
            registerSolvedAndPersist()
        }
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

        // Also persist Smart Boost locks (by coord) whenever we snapshot
        persistBoostLocks()
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

// MARK: - Smart Boost (auto with non-adjacent preference)

extension GameState {
    /// Reveals (places) one correct tile at a random eligible coord.
    /// Prefers coords that are NOT orthogonally adjacent to the last auto-boost;
    /// falls back to adjacent if no other options exist.
    /// Applies +movePenalty (without adding a normal move) and persists.
    func applySmartBoost(movePenalty: Int) -> Bool {
        guard let solution = self.solution, solution.count == 4 else {
            NSLog("SmartBoost(auto): no solution cached for today")
            return false
        }

        // Bag availability (handles duplicates)
        var bagCounts: [Character: Int] = [:]
        for t in tiles where t.location == .bag {
            bagCounts[t.letter, default: 0] += 1
        }

        // Build candidate coords: not already correct AND needed letter is in the bag
        var candidates: [BoardCoord] = []
        for r in 0..<4 {
            let rowChars = Array(solution[r])
            for c in 0..<4 {
                let coord = BoardCoord(row: r, col: c)
                let needed = rowChars[c]

                if let existing = tile(at: coord), existing.letter == needed { continue }
                guard let count = bagCounts[needed], count > 0 else { continue }
                candidates.append(coord)
            }
        }

        guard !candidates.isEmpty else { return false }

        // Prefer non-adjacent to the last placement; fallback to all if none
        let pool: [BoardCoord]
        if let last = lastSmartBoostCoord {
            let nonAdjacent = candidates.filter { !isAdjacent($0, last) }
            pool = nonAdjacent.isEmpty ? candidates : nonAdjacent
        } else {
            pool = candidates
        }

        guard let chosen = pool.randomElement() else { return false }

        // Place the correct letter at `chosen` (no normal move counted)
        let needed = Array(solution[chosen.row])[chosen.col]

        // If target is occupied, move that tile back to bag first
        if let occupying = tile(at: chosen) {
            // If occupant is locked (shouldn't happen), block boost (safety)
            if boostedLockedTileIDs.contains(occupying.id) { return false }
            moveTileTo(occupying, to: .bag, countAsMove: false)
        }

        // Find the actual bag tile with the needed letter
        guard let bagIdx = tiles.firstIndex(where: { $0.location == .bag && $0.letter == needed }) else {
            return false
        }

        var chosenTile = tiles[bagIdx]
        chosenTile.hasBeenPlacedOnce = true
        tiles[bagIdx] = chosenTile
        moveTileTo(chosenTile, to: .board(chosen), countAsMove: false)

        moveCount += movePenalty
        lastSmartBoostCoord = chosen

        // 🟩 Mark as locked (runtime + persisted by coord)
        boostedLockedTileIDs.insert(chosenTile.id)
        boostedLockedCoords.insert(coordKey(chosen))
        persistBoostLocks()

        checkIfSolved()
        persistProgressSnapshot()
        return true
    }

    // Helper: 4-neighbor (orthogonal) adjacency
    private func isAdjacent(_ a: BoardCoord, _ b: BoardCoord) -> Bool {
        abs(a.row - b.row) + abs(a.col - b.col) == 1
    }
}

// MARK: - Levels: start a session from a seed (prototype 4×4)
extension GameState {
    /// Starts a level session from a fixed seed. Does NOT touch Daily persistence.
    /// For now this uses your 4-letter dictionary; theme dictionaries come later.
    func startLevelSession(seed: UInt64, dictionaryID: String? = nil) {
        isLevelMode = true
        moveCount = 0
        solved = false
        invalidHighlights = []
        lastSmartBoostCoord = nil
        boostedLockedTileIDs.removeAll()

        // Load words (later: switch on dictionaryID)
        let words = DictionaryLoader.loadFourLetterWords()
        let gen = WordSquareGenerator(words: words)

        // Reuse your seeded RNG helper to get determinism from a seed via Date
        let date = Date(timeIntervalSince1970: TimeInterval(seed % 31_536_000)) // ~1y cycle
        var rng: any RandomNumberGenerator = SeededRNG.dailySeed(version: "LEVEL_v1", date: date)

        if let puzzle = gen.generateDaily(rng: &rng) {
            self.solution = puzzle.solution
            let bag = String(puzzle.letters.map { Character($0.lowercased()) })
            buildTiles(from: bag) // resets board & tiles; no run-state save
        } else {
            // Fallback (rare)
            let fallback = Array("tetradwordpuzzlega".prefix(16))
            buildTiles(from: String(fallback))
            self.solution = nil
        }
    }
}


// MARK: - Boost lock persistence (by coord)

extension GameState {
    private func lockKey(for dayUTC: String) -> String { "tetrad_locks_\(dayUTC)" }
    private func coordKey(_ coord: BoardCoord) -> String { "\(coord.row),\(coord.col)" }
    private func parseCoordKey(_ s: String) -> BoardCoord? {
        let parts = s.split(separator: ",")
        guard parts.count == 2, let r = Int(parts[0]), let c = Int(parts[1]) else { return nil }
        return BoardCoord(row: r, col: c)
    }

    private func persistBoostLocks() {
        guard let id = identity else { return }
        let key = lockKey(for: id.dayUTC)
        UserDefaults.standard.set(Array(boostedLockedCoords), forKey: key)
    }

    private func loadBoostLocks(for dayUTC: String) {
        let key = lockKey(for: dayUTC)
        let arr = (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
        boostedLockedCoords = Set(arr)

        // Map coords → current tile IDs (IDs change across sessions)
        boostedLockedTileIDs.removeAll()
        for s in boostedLockedCoords {
            if let coord = parseCoordKey(s), let t = tile(at: coord) {
                boostedLockedTileIDs.insert(t.id)
            }
        }
    }

    private func clearBoostLocks(for dayUTC: String) {
        let key = lockKey(for: dayUTC)
        UserDefaults.standard.removeObject(forKey: key)
    }
}
