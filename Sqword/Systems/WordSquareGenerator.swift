import Foundation

struct GeneratedPuzzle {
    let letters: [Character]   // 16 letters
    let solution: [String]     // 4 strings
}

final class WordSquareGenerator {
    // MARK: - Data
    private let trie: Trie
    private let all4: [String]

    // Fast lookups
    private var prefixMemo: [String: [String]] = [:]    // prefix -> candidates
    private var firstLetterBuckets: [Character: [String]] = [:]

    // MARK: - Init
    init(words: [String]) {
        // Keep only clean 4-letter alphabetic words, lowercased
        let normalized = words
            .map { $0.lowercased() }
            .filter { $0.count == 4 && $0.allSatisfy(\.isLetter) }

        self.trie = Trie(words: normalized)
        self.all4 = trie.wordsOfLength(4)

        // Seed first-letter buckets once (micro-optimization)
        var buckets: [Character: [String]] = [:]
        for w in all4 {
            if let ch = w.first { buckets[ch, default: []].append(w) }
        }
        self.firstLetterBuckets = buckets
    }

    // MARK: - Public
    /// Try to generate a daily puzzle. Will retry with different starts and stop
    /// early if a time budget is exceeded (keeps the UI snappy).
    func generateDaily(
        rng: inout any RandomNumberGenerator,
        maxRetries: Int = 50,
        timeBudgetMillis: Int = 500
    ) -> GeneratedPuzzle? {
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeBudgetMillis) * 1_000_000

        let starts = all4.shuffled(using: &rng)
        var seenBags = Set<String>()
        var attempt = 0

        for w in starts {
            attempt += 1

            // Stop if we ran out of budget
            if DispatchTime.now().uptimeNanoseconds > deadline {
//                NSLog("⏱️ WordSquare: budget \(timeBudgetMillis)ms exhausted after \(attempt) starts; no puzzle.")
                return nil
            }

            if let square = buildSquare(startWord: w, deadline: deadline) {
                let bag = Array(square.joined())
                var shuffled = bag
                shuffled.shuffle(using: &rng)

                if isUniqueSolution(bag: shuffled, cap: 2) {
                    // 🔎 DEBUG: print the solution rows (and columns for sanity)
                    let rowsText = square.joined(separator: " | ")
                    let rowsArr = square.map(Array.init)  // convert each row into [Character]
                    let colsText = (0..<4)
                        .map { c in String(rowsArr.map { $0[c] }) }
                        .joined(separator: " | ")

//                    NSLog("🧩 Puzzle solution ROWS: \(rowsText)")
//                    NSLog("🧩 Puzzle solution COLS: \(colsText)")

                    let bagKey = String(bag.sorted())
                    if seenBags.insert(bagKey).inserted {
                        return GeneratedPuzzle(letters: shuffled, solution: square)
                    }
                } else {
                    // Optional: log that a non-unique bag was rejected
//                    NSLog("🚫 Rejected bag (not unique). Start word: \(w)")
                }
            }


            if attempt >= maxRetries {
//                NSLog("⚠️ WordSquare: reached maxRetries=\(maxRetries) without a result.")
                break
            }
        }

        return nil
    }

    // MARK: - Core search (fast)
    /// Build a word square starting from a chosen first word, honoring a time budget.
    private func buildSquare(startWord: String, deadline: UInt64) -> [String]? {
        var square: [String] = [startWord]
        var used: Set<String> = [startWord]          // track words already used
        prefixMemo.removeAll(keepingCapacity: true)
        return dfs(&square, used: &used, deadline: deadline)
    }


    /// Depth-first search with aggressive prefix pruning & memoized candidates.
    private func dfs(_ square: inout [String], used: inout Set<String>, deadline: UInt64) -> [String]? {
        @inline(__always) func timedOut() -> Bool {
            DispatchTime.now().uptimeNanoseconds > deadline
        }

        let n = 4
        let k = square.count

        // Finished: validate columns and ensure all 4 rows are distinct
        if k == n {
            for c in 0..<n {
                var col = ""
                for r in 0..<n {
                    let ch = square[r][square[r].index(square[r].startIndex, offsetBy: c)]
                    col.append(ch)
                }
                if !trie.contains(col) { return nil }
            }
            if Set(square).count != n { return nil }   // no duplicate row words
            return square
        }

        if timedOut() { return nil }

        // Build column prefixes from existing rows
        var prefixes: [String] = Array(repeating: "", count: n)
        for c in 0..<n {
            var s = ""
            for r in 0..<k {
                let ch = square[r][square[r].index(square[r].startIndex, offsetBy: c)]
                s.append(ch)
            }
            if !s.isEmpty && !trie.hasPrefix(s) { return nil } // prune dead branches
            prefixes[c] = s
        }

        // For next row at index k: for each c in 0..<k, newRow[c] must equal square[c][k]
        var fixedPositions: [(Int, Character)] = []
        let rowsArr = square.map(Array.init)  // [[Character]]
        for c in 0..<k {
            let needed = rowsArr[c][k]
            fixedPositions.append((c, needed))
        }

        // Seed candidate list smartly
        let seed: [String]
        if let firstFixed = fixedPositions.first, firstFixed.0 == 0,
           let bucket = firstLetterBuckets[firstFixed.1] {
            seed = bucket
        } else {
            seed = all4
        }

        // Build candidate rows (skip duplicates; keep prefixes viable)
        var rowCandidates: [String] = []
        rowCandidates.reserveCapacity(64)

        outer: for w in seed {
            if used.contains(w) { continue }              // 💡 no duplicate rows
            let arr = Array(w)

            for (pos, ch) in fixedPositions {
                if arr[pos] != ch { continue outer }
            }
            for c in 0..<n {
                var col = prefixes[c]
                col.append(arr[c])
                if !trie.hasPrefix(col) { continue outer }
            }
            rowCandidates.append(w)
        }

        // Simple heuristic: prefer more distinct letters
        rowCandidates.sort { Set($0).count > Set($1).count }

        for cand in rowCandidates {
            square.append(cand)
            used.insert(cand)
            if let done = dfs(&square, used: &used, deadline: deadline) { return done }
            used.remove(cand)
            square.removeLast()
            if timedOut() { return nil }
        }
        return nil
    }



    // MARK: - Prefix → candidates (memoized)
    /// Memoized candidate fetch; currently unused in dfs because fixed-position filtering is faster for 4 letters,
    /// but kept here in case you want to switch strategies or reuse elsewhere.
    private func candidates(forPrefix p: String) -> [String] {
        if p.isEmpty { return all4 }
        if let hit = prefixMemo[p] { return hit }
        guard trie.hasPrefix(p) else { prefixMemo[p] = []; return [] }
        // For 4-letter words, a linear filter is cache-friendly and very fast
        let cands = all4.filter { $0.hasPrefix(p) }
        prefixMemo[p] = cands
        return cands
    }

    // MARK: - Uniqueness check (pruned)
    /// Ensure that only one word square can be made from the letter-bag multiset.
    /// `cap` stops after finding 2 solutions (we only need to know if >1 exists).
    private func isUniqueSolution(bag: [Character], cap: Int = 2) -> Bool {
        let n = 4
        var counts: [Character: Int] = [:]
        counts.reserveCapacity(16)
        for ch in bag { counts[ch, default: 0] += 1 }

        var grid = Array(repeating: "", count: n)
        var solutions = 0

        @inline(__always)
        func canUse(_ w: String) -> Bool {
            // Quick check using the multiset counts
            var tmp = counts
            for ch in w {
                let v = tmp[ch] ?? 0
                if v == 0 { return false }
                tmp[ch] = v - 1
            }
            counts = tmp
            return true
        }
        @inline(__always)
        func unuse(_ w: String) {
            for ch in w { counts[ch, default: 0] += 1 }
        }

        @inline(__always)
        func colPrefixOK(_ r: Int) -> Bool {
            for c in 0...r {
                var col = ""
                for k in 0...r {
                    let rowStr = grid[k]
                    let ch = rowStr[rowStr.index(rowStr.startIndex, offsetBy: c)]
                    col.append(ch)
                }
                if !trie.hasPrefix(col) { return false }
            }
            return true
        }

        @inline(__always)
        func finalizeOK() -> Bool {
            for c in 0..<n {
                var col = ""
                for r in 0..<n {
                    let rowStr = grid[r]
                    let ch = rowStr[rowStr.index(rowStr.startIndex, offsetBy: c)]
                    col.append(ch)
                }
                if !trie.contains(col) { return false }
            }
            return true
        }

        // Small optimization: pre-filter the dictionary to only words whose letters
        // can be drawn from the bag (so we don't try impossible rows).
        // Build a list once; reuse in DFS.
        let viableWords: [String] = all4.filter { w in
            var need: [Character: Int] = [:]
            for ch in w { need[ch, default: 0] += 1 }
            for (ch, n) in need {
                if (counts[ch] ?? 0) < n { return false }
            }
            return true
        }

        func dfs(_ row: Int) {
            if solutions >= cap { return } // Early termination as soon as >1 found
            if row == n {
                if finalizeOK() { solutions += 1 }
                return
            }
            for w in viableWords {
                if canUse(w) {
                    grid[row] = w
                    if colPrefixOK(row) { dfs(row + 1) }
                    unuse(w)
                    if solutions >= cap { return }
                }
            }
        }

        dfs(0)
        return solutions == 1
    }
}
