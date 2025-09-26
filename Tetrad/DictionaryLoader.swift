import Foundation

enum DictionaryLoader {
    /// Minimal placeholder list for compilation/demo.
    static let fallbackFourLetterWords: [String] = [
        "star","tare","area","read",
        "lend","else","need","deer",
        "chip","chop","inch","pica",
        "dome","dove","mode","mend",
        "tide","tile","time","tame",
        "rope","rode","rose","nose",
        "east","ease","earn","near",
        "peel","peal","pale","sale",
        "mall","tall","ball","fall"
    ]

    static func loadFourLetterWords() -> [String] {
        if let url = Bundle.main.url(forResource: "words4", withExtension: "txt"),
           let contents = try? String(contentsOf: url) {
            let words = contents
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { $0.count == 4 && !$0.isEmpty }

            if !words.isEmpty {
                print("✅ Loaded \(words.count) words from words4.txt")
                return words
            } else {
                print("⚠️ words4.txt was found but had no valid entries — using fallback")
            }
        } else {
            print("⚠️ words4.txt not found in bundle — using fallback")
        }

        print("✅ Loaded \(fallbackFourLetterWords.count) fallback words")
        return fallbackFourLetterWords
    }
}
