import Foundation

struct GeneratedPuzzle {
    let letters: [Character]   // 16 letters
    let solution: [String]     // 4 strings
}

final class WordSquareGenerator {
    private let trie: Trie
    private let all4: [String]

    init(words: [String]) {
        self.trie = Trie(words: words.filter{ $0.count == 4 })
        self.all4 = trie.wordsOfLength(4)
    }

    func generateDaily(rng: inout any RandomNumberGenerator, maxRetries: Int = 50) -> GeneratedPuzzle? {
        // Try multiple times to find a unique puzzle
        for _ in 0..<maxRetries {
            if let square = buildSquare(rng: &rng) {
                let bag = Array(square.joined())
                let shuffled = bag.shuffled(using: &rng)
                if isUniqueSolution(bag: shuffled) {
                    return GeneratedPuzzle(letters: shuffled, solution: square)
                }
            }
        }
        return nil
    }

    private func buildSquare(rng: inout any RandomNumberGenerator) -> [String]? {
        let candidates = all4.shuffled(using: &rng)
        var grid = Array(repeating: "", count: 4)
        var used = Set<String>()

        func prefixOK(_ r: Int) -> Bool {
            // Check column prefixes 0..r
            for c in 0...r {
                var col = ""
                for k in 0...r {
                    let rowStr = grid[k]
                    guard rowStr.count == 4 else { return false }
                    let ch = rowStr[rowStr.index(rowStr.startIndex, offsetBy: c)]
                    col.append(ch)
                }
                if !trie.hasPrefix(col) { return false }
            }
            return true
        }

        func finalizeOK() -> Bool {
            for c in 0..<4 {
                var col = ""
                for r in 0..<4 {
                    let rowStr = grid[r]
                    let ch = rowStr[rowStr.index(rowStr.startIndex, offsetBy: c)]
                    col.append(ch)
                }
                if !trie.contains(col) { return false }
            }
            return true
        }

        func dfs(_ row: Int) -> Bool {
            if row == 4 { return finalizeOK() }
            for w in candidates where !used.contains(w) {
                grid[row] = w
                if prefixOK(row) {
                    used.insert(w)
                    if dfs(row+1) { return true }
                    used.remove(w)
                }
            }
            return false
        }

        return dfs(0) ? grid : nil
    }

    /// Uniqueness: ensure that only one word square can be made from the letter-bag multiset.
    private func isUniqueSolution(bag: [Character], cap: Int = 2) -> Bool {
        var counts: [Character: Int] = [:]
        for ch in bag { counts[ch, default: 0] += 1 }

        var grid = Array(repeating: "", count: 4)
        var solutions = 0

        func canUse(_ w: String) -> Bool {
            var tmp = counts
            for ch in w {
                if let v = tmp[ch], v > 0 {
                    tmp[ch] = v - 1
                } else {
                    return false
                }
            }
            counts = tmp
            return true
        }
        func unuse(_ w: String) {
            for ch in w { counts[ch, default: 0] += 1 }
        }

        func colPrefixOK(_ r: Int) -> Bool {
            for c in 0...r {
                var col = ""
                for k in 0...r {
                    let rowStr = grid[k]
                    guard rowStr.count == 4 else { return false }
                    let ch = rowStr[rowStr.index(rowStr.startIndex, offsetBy: c)]
                    col.append(ch)
                }
                if !trie.hasPrefix(col) { return false }
            }
            return true
        }

        func finalizeOK() -> Bool {
            for c in 0..<4 {
                var col = ""
                for r in 0..<4 {
                    let rowStr = grid[r]
                    let ch = rowStr[rowStr.index(rowStr.startIndex, offsetBy: c)]
                    col.append(ch)
                }
                if !trie.contains(col) { return false }
            }
            return true
        }

        func dfs(_ row: Int) {
            if solutions >= cap { return } // Early stop if more than one
            if row == 4 {
                if finalizeOK() { solutions += 1 }
                return
            }
            for w in trie.wordsOfLength(4) {
                if canUse(w) {
                    grid[row] = w
                    if colPrefixOK(row) { dfs(row+1) }
                    unuse(w)
                    if solutions >= cap { return }
                }
            }
        }

        dfs(0)
        return solutions == 1
    }
}
