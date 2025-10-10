import Foundation
import SwiftUI

final class GameState: ObservableObject {
    // MARK: - Published state
    @Published var tiles: [LetterTile] = []
    @Published var board: [[UUID?]] = Array(repeating: Array(repeating: nil, count: 4), count: 4)
    @Published var solved: Bool = false
    @Published var invalidHighlights: Set<Int> = []   // indices 0..7 for rows/cols if needed

    @Published var moveCount: Int = 0
    @Published var streak: Int = UserDefaults.standard.integer(forKey: "tetrad_streak")
    @Published var lastSolvedDateUTC: String? = UserDefaults.standard.string(forKey: "tetrad_lastSolvedUTC")

    // Level mode & World Word flags
    @Published var isLevelMode: Bool = false
    @Published var worldWord: String? = nil
    @Published var worldWordIndex: Int? = nil                // 0..3 (row == col)
    @Published var worldProtectedCoords: Set<BoardCoord> = []// union of row+col at index
    @Published var worldLockedTileIDs: Set<UUID> = []        // tiles locked due to World Word
    @Published var worldShimmerIDs: Set<UUID> = []           // for 2s shimmer effect on lock
    @Published var worldWordJustCompleted: Bool = false      // flips true once when completed
    @Published var worldIndex: Int? = nil                    // if you read it elsewhere



    // Smart Boost locks (runtime + persisted-by-coord for Daily)
    @Published var boostedLockedTileIDs: Set<UUID> = []      // runtime-only (IDs change per session)
    private var boostedLockedCoords: Set<String> = []        // persisted as "r,c" strings

    // MARK: - Private state
    private let versionKey = "TETRAD_v1"
    private var identity: PuzzleIdentity?
    private var lastSmartBoostCoord: BoardCoord? = nil
    private var solution: [String]? = nil                    // in-memory (rows)

    // MARK: - Lifecycle
    init() {}

    // MARK: - Daily bootstrap / generation / restore
    @MainActor
    func bootstrapForToday(date: Date = Date()) {
        let todayKey = currentUTCDateKey(date)
        NSLog("bootstrapForToday → \(todayKey)")
        isLevelMode = false

        generateNewDailyIdentity(date: date)

        if let id = identity {
            buildTiles(from: id.bag)
        } else {
            NSLog("⚠️ bootstrapForToday: identity missing after generation for \(todayKey)")
        }

        restoreRunStateOrStartFresh(for: todayKey)
        loadBoostLocks(for: todayKey) // map coord locks → tile IDs
    }

    private func generateNewDailyIdentity(date: Date) {
        let words = DictionaryLoader.loadFourLetterWords()
        let gen = WordSquareGenerator(words: words)
        var rng: any RandomNumberGenerator = SeededRNG.dailySeed(version: versionKey, date: date)

        if let puzzle = gen.generateDaily(rng: &rng) {
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
        moveCount = 0

        // Reset boost locks for the new bag (IDs change)
        lastSmartBoostCoord = nil
        boostedLockedTileIDs = []
        // Do not clear boostedLockedCoords here; that persists per day-key and is loaded later.
        // Clear world-word locks/flags; they are per-session (Level only)
        worldLockedTileIDs.removeAll()
        worldShimmerIDs.removeAll()
        worldWordJustCompleted = false
    }

    private func restoreRunStateOrStartFresh(for todayKey: String) {
        if let run = Persistence.loadRunState(), run.lastPlayedDayUTC == todayKey {
            moveCount = run.moves
            solved = run.solvedToday
            streak = run.streak

            // Reset board & tiles to bag
            board = Array(repeating: Array(repeating: nil, count: 4), count: 4)
            for i in tiles.indices {
                var t = tiles[i]
                t.location = .bag
                t.hasBeenPlacedOnce = false
                tiles[i] = t
            }
            // Re-apply placements in order (consume letters from bag)
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
        clearBoostLocks(for: todayKey)
        let run = RunState(moves: 0, solvedToday: false, placements: [], streak: streak, lastPlayedDayUTC: todayKey)
        Persistence.saveRunState(run)
    }

    // MARK: - Daily “new puzzle”
    @MainActor
    func newDailyPuzzle(date: Date = Date()) {
        NSLog("🟡 newDailyPuzzle() called for \(currentUTCDateKey(date))")
        let dict = DictionaryLoader.loadFourLetterWords()
        NSLog("📚 Tetrad dictionary loaded: \(dict.count) words")
        if let id = identity { clearBoostLocks(for: id.dayUTC) }
        Persistence.clearForNewDay()
        generateNewDailyIdentity(date: date)
        resetForNewIdentity(todayKey: currentUTCDateKey(date))
        persistProgressSnapshot()
    }

    // MARK: - Basic helpers
    func tile(at coord: BoardCoord) -> LetterTile? {
        guard let id = board[coord.row][coord.col] else { return nil }
        return tiles.first(where: { $0.id == id })
    }

    private func solutionChar(at coord: BoardCoord) -> Character? {
        guard let solution = self.solution, solution.count == 4 else { return nil }
        let row = Array(solution[coord.row])
        guard coord.col < row.count else { return nil }
        return row[coord.col]
    }

    private func isCorrect(_ letter: Character, at coord: BoardCoord) -> Bool {
        solutionChar(at: coord) == letter
    }

    // MARK: - Placement / removal
    @MainActor
    func placeTile(_ tile: LetterTile, at coord: BoardCoord) {
        // 🚫 Cannot move a locked tile, and cannot displace a locked occupant.
        if boostedLockedTileIDs.contains(tile.id) || worldLockedTileIDs.contains(tile.id) { return }
        if let occ = self.tile(at: coord),
           boostedLockedTileIDs.contains(occ.id) || worldLockedTileIDs.contains(occ.id) { return }

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

        // Bounce occupant (no move counted for bounced tile)
        if let occupying = self.tile(at: coord) {
            if case .board(let prev) = tile.location {
                moveTileTo(occupying, to: .board(prev), countAsMove: false)
            } else {
                moveTileTo(occupying, to: .bag, countAsMove: false)
            }
        }

        // Commit placement
        t.location = .board(coord)
        if let idx = tiles.firstIndex(where: { $0.id == t.id }) { tiles[idx] = t }
        board[coord.row][coord.col] = t.id

        // 🔒 Auto-lock for World Word cells when correct
        if worldProtectedCoords.contains(coord),
           let sol = solution, sol.count == 4
        {
            // If case might differ between solution and tiles, normalize:
            let expected = Array(sol[coord.row])[coord.col]
            // let matches = String(expected).uppercased().first! == String(t.letter).uppercased().first!
            let matches = (expected == t.letter)  // keep if your data already matches case

            if matches {
                // Insert returns (inserted: Bool, memberAfterInsert: Element)
                let justLocked = worldLockedTileIDs.insert(t.id).inserted
                if justLocked {
                    NSLog("🔒 World-lock at (\(coord.row),\(coord.col)) letter \(t.letter) id=\(t.id)")

                    // 2s shimmer (one-shot)
                    worldShimmerIDs.insert(t.id)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.worldShimmerIDs.remove(t.id)
                    }
                }

                // This can remain outside the justLocked guard so the “complete” check
                // runs even if the last cell was already locked (e.g., resume).
                checkWorldWordComplete()
            }
        }


        if isMove { moveCount += 1 }
        checkIfSolved()
        persistProgressSnapshot()
    }

    @MainActor
    func removeTile(from coord: BoardCoord) {
        guard let id = board[coord.row][coord.col],
              let idx = tiles.firstIndex(where: { $0.id == id }) else { return }

        // 🚫 Do not remove if locked by Boost or World Word
        if boostedLockedTileIDs.contains(id) || worldLockedTileIDs.contains(id) { return }

        var t = tiles[idx]
        t.location = .bag
        tiles[idx] = t
        board[coord.row][coord.col] = nil

        // If removing affects the World Word completion, recompute banner state
        if worldProtectedCoords.contains(coord) {
            checkWorldWordComplete()
        }

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

    // MARK: - Solved / streak
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
        guard let solution = self.solution, solution.count == 4 else { return }

        for r in 0..<4 {
            for c in 0..<4 {
                guard let id = board[r][c],
                      let tile = tiles.first(where: { $0.id == id }) else {
                    return
                }
                let correctChar = Array(solution[r])[c]
                if tile.letter != correctChar { return }
            }
        }

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

    // MARK: - World-word helpers (completion / protection)
    @MainActor
    private func checkWorldWordComplete() {
        guard !worldProtectedCoords.isEmpty else { return }

        for coord in worldProtectedCoords {
            guard let id = board[coord.row][coord.col],
                  let tile = tiles.first(where: { $0.id == id }),
                  isCorrect(tile.letter, at: coord) else {
                worldWordJustCompleted = false
                return
            }
        }

        if worldWordJustCompleted == false {
            worldWordJustCompleted = true
            NSLog("✨ World Word complete: \(worldWord ?? "(unknown)") at index \(worldWordIndex ?? -1)")
        }
    }

    /// Legacy helper → route to protection builder (kept to avoid breaking callers).
    func setWorldIndex(_ k: Int?) {
        setWorldWordProtection(index: k)
    }

    /// Build or clear protection (row k + col k)
    func setWorldWordProtection(index k: Int?) {
        worldLockedTileIDs.removeAll()
        worldShimmerIDs.removeAll()
        worldWordJustCompleted = false
        worldIndex = k

        guard let k else {
            worldProtectedCoords.removeAll()
            return
        }
        var s = Set<BoardCoord>()
        for i in 0..<4 {
            s.insert(.init(row: k, col: i))
            s.insert(.init(row: i, col: k))
        }
        worldProtectedCoords = s
    }

    // MARK: - Level session (theme-aware)
    /// Starts a *Level* game using a world dictionary + base list.
    /// We try several attempts to produce a square that includes at least
    /// one word from the world list; that one becomes the "World Word" (row==col).
    @MainActor
    func startLevelSession(seed: UInt64, dictionaryID: String) {
        isLevelMode = true
        moveCount = 0
        solved = false

        // Clear world state for a fresh level (UI/runtime flags)
        worldWord = nil
        worldWordIndex = nil
        worldProtectedCoords.removeAll()
        worldLockedTileIDs.removeAll()
        worldShimmerIDs.removeAll()
        worldWordJustCompleted = false
        lastSmartBoostCoord = nil
        boostedLockedTileIDs.removeAll() // boosts are level-local

        // Load dictionaries (normalize to lowercase 4-letter)
        let baseRaw = DictionaryLoader.loadFourLetterWords()
        let base = baseRaw.map { $0.lowercased() }.filter { $0.count == 4 && $0.allSatisfy(\.isLetter) }

        let themedRaw = DictionaryLoader.loadWorldDictionary(named: dictionaryID)
        let themed = themedRaw.map { $0.lowercased() }.filter { $0.count == 4 && $0.allSatisfy(\.isLetter) }
        let themedSet = Set(themed)

        let all = Array(Set(base).union(themedSet))
        let gen = WordSquareGenerator(words: all)

        var foundSolution: [String]? = nil
        var foundLetters: [Character]? = nil
        var theWorldIndex: Int? = nil
        var usedThemedWord = false

        // Try a number of attempts to find a solution that includes a themed word
        for attempt in 0..<120 {
            var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
            if let puzzle = gen.generateDaily(rng: &rng) {
                if let idx = puzzle.solution.firstIndex(where: { themedSet.contains($0) }) {
                    foundSolution = puzzle.solution
                    foundLetters  = puzzle.letters
                    theWorldIndex = idx
                    usedThemedWord = true
                    break
                }
                if foundSolution == nil {
                    foundSolution = puzzle.solution
                    foundLetters  = puzzle.letters
                    theWorldIndex = Int((seed &+ UInt64(attempt)) % 4) // stable-ish fallback
                }
            }
        }

        guard
            let solution = foundSolution,
            let letters  = foundLetters,
            let wIndex   = theWorldIndex
        else {
            NSLog("❌ Level start failed; falling back to Daily bootstrap")
            bootstrapForToday()
            return
        }

        if themedSet.isEmpty {
            NSLog("⚠️ Level start (\(dictionaryID)): themed set is empty; generic square used.")
        } else if !usedThemedWord {
            NSLog("ℹ️ Level start (\(dictionaryID)): no themed word hit after attempts; using fallback square.")
        } else {
            NSLog("✅ Level start (\(dictionaryID)): world word = \(solution[wIndex]) @ index \(wIndex)")
        }

        // Record solution + build tiles/bag
        self.solution = solution
        let bag = String(letters) // letters already lowercased characters
        self.identity = PuzzleIdentity(dayUTC: "LEVEL-\(seed)", bag: bag)

        buildTiles(from: bag)

        // Mark the World Word & protect its row/col
        self.worldWord = solution[wIndex]
        self.worldWordIndex = wIndex

        var coords: Set<BoardCoord> = []
        for c in 0..<4 { coords.insert(.init(row: wIndex, col: c)) }
        for r in 0..<4 { coords.insert(.init(row: r, col: wIndex)) }
        self.worldProtectedCoords = coords

        // ⬇️ Try to RESUME this level from a saved snapshot (if identity matches)
        if let id = self.identity,
           var run = Persistence.loadRunState(),
           run.lastPlayedDayUTC == id.dayUTC {

            // Restore counters
            self.moveCount = run.moves
            self.solved    = run.solvedToday

            // Reset board & return all tiles to bag
            self.board = Array(repeating: Array(repeating: nil, count: 4), count: 4)
            for i in tiles.indices {
                var t = tiles[i]
                t.location = .bag
                t.hasBeenPlacedOnce = false
                tiles[i] = t
            }

            // Re-apply placements (consume matching letters from bag)
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

            // Rebuild World-Word locks for correctly placed protected cells
            self.worldLockedTileIDs.removeAll()
            for coord in self.worldProtectedCoords {
                if let t = tile(at: coord), isCorrect(t.letter, at: coord) {
                    self.worldLockedTileIDs.insert(t.id)
                }
            }
            checkWorldWordComplete()

            persistProgressSnapshot() // keep snapshot consistent
            return
        }

        // Fresh start (no snapshot found)
        persistProgressSnapshot()
    }


    // MARK: - Persistence snapshots
    
    @MainActor
    private func restoreLevelSnapshotIfAvailable() -> Bool {
        guard let id = identity else { return false }
        guard var run = Persistence.loadRunState(),
              run.lastPlayedDayUTC == id.dayUTC else { return false }

        // Restore counters/flags
        moveCount = run.moves
        solved    = run.solvedToday

        // Reset board & return all tiles to the bag
        board = Array(repeating: Array(repeating: nil, count: 4), count: 4)
        for i in tiles.indices {
            var t = tiles[i]
            t.location = .bag
            t.hasBeenPlacedOnce = false
            tiles[i] = t
        }

        // Re-apply placements (match by letter from bag pool)
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

        // Rebuild World-Word locks for correctly placed protected cells
        worldLockedTileIDs.removeAll()
        for coord in worldProtectedCoords {
            if let t = tile(at: coord), isCorrect(t.letter, at: coord) {
                worldLockedTileIDs.insert(t.id)
            }
        }
        // Re-evaluate completion flag
        checkWorldWordComplete()

        return true
    }
    
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
        persistBoostLocks() // keep daily boost locks in sync
    }

    private func registerSolvedAndPersist() {
        guard let id = identity else { return }
        if var run = Persistence.loadRunState(), !run.solvedToday {
            run.solvedToday = true
            run.moves = moveCount
            run.streak = streak
            run.lastPlayedDayUTC = id.dayUTC
            Persistence.saveRunState(run)
        }
        persistProgressSnapshot()
    }
}


// MARK: - Smart Boost (auto, non-adjacent preference, avoids World Word cells)
extension GameState {
    @MainActor
    func applySmartBoost(movePenalty: Int) -> Bool {
        guard let solution = self.solution, solution.count == 4 else {
            NSLog("SmartBoost(auto): no solution cached for today")
            return false
        }

        // Bag availability
        var bagCounts: [Character: Int] = [:]
        for t in tiles where t.location == .bag { bagCounts[t.letter, default: 0] += 1 }

        // Candidates: not already correct, available in bag, and not in protected world cells
        var candidates: [BoardCoord] = []
        for r in 0..<4 {
            let rowChars = Array(solution[r])
            for c in 0..<4 {
                let coord = BoardCoord(row: r, col: c)
                if worldProtectedCoords.contains(coord) { continue } // avoid World Word cells
                let needed = rowChars[c]
                if let existing = tile(at: coord), existing.letter == needed { continue }
                guard let count = bagCounts[needed], count > 0 else { continue }
                candidates.append(coord)
            }
        }
        guard !candidates.isEmpty else { return false }

        // Prefer non-adjacent to last placement
        let pool: [BoardCoord]
        if let last = lastSmartBoostCoord {
            let nonAdj = candidates.filter { abs($0.row - last.row) + abs($0.col - last.col) != 1 }
            pool = nonAdj.isEmpty ? candidates : nonAdj
        } else {
            pool = candidates
        }
        guard let chosen = pool.randomElement() else { return false }

        let needed = Array(solution[chosen.row])[chosen.col]

        // Clear occupant (safety: do not dislodge a locked piece)
        if let occ = tile(at: chosen) {
            if boostedLockedTileIDs.contains(occ.id) || worldLockedTileIDs.contains(occ.id) { return false }
            moveTileTo(occ, to: .bag, countAsMove: false)
        }

        guard let bagIdx = tiles.firstIndex(where: { $0.location == .bag && $0.letter == needed }) else {
            return false
        }

        var chosenTile = tiles[bagIdx]
        chosenTile.hasBeenPlacedOnce = true
        tiles[bagIdx] = chosenTile
        moveTileTo(chosenTile, to: .board(chosen), countAsMove: false)

        moveCount += movePenalty
        lastSmartBoostCoord = chosen

        // Lock the boosted tile and persist by coord (Daily)
        boostedLockedTileIDs.insert(chosenTile.id)
        boostedLockedCoords.insert(coordKey(chosen))
        persistBoostLocks()

        checkIfSolved()
        persistProgressSnapshot()
        return true
    }
}

// MARK: - Boost lock persistence (by coord for Daily)
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
