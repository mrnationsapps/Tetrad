import Foundation

final class Trie {
    final class Node {
        var children: [Character: Node] = [:]
        var isEnd: Bool = false
    }

    private let root = Node()
    private let lengthIndex: [Int: [String]]

    init(words: [String]) {
        var norm: [String] = []
        var byLen: [Int: [String]] = [:]
        for w in words {
            let s = w.lowercased()
            guard s.count > 0, s.allSatisfy({ $0.isLetter }) else { continue }
            norm.append(s)
            byLen[s.count, default: []].append(s)
        }

        // initialize stored property before calling methods
        self.lengthIndex = byLen

        // now safe to insert
        for s in norm {
            insert(s)
        }
    }

    func insert(_ word: String) {
        var node = root
        for ch in word {
            if node.children[ch] == nil {
                node.children[ch] = Node()
            }
            node = node.children[ch]!
        }
        node.isEnd = true
    }

    func hasPrefix(_ prefix: String) -> Bool {
        var node = root
        for ch in prefix {
            guard let next = node.children[ch] else { return false }
            node = next
        }
        return true
    }

    func contains(_ word: String) -> Bool {
        var node = root
        for ch in word {
            guard let next = node.children[ch] else { return false }
            node = next
        }
        return node.isEnd
    }

    func wordsOfLength(_ len: Int) -> [String] {
        return lengthIndex[len] ?? []
    }
}
