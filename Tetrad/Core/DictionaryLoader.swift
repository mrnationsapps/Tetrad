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

    static func loadFourLetterWords(filename: String = "words4") -> [String] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "txt"),
              let raw = try? String(contentsOf: url)
        else { return [] }
        return raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.count == 4 }
    }
    
    /// load a *world* dictionary by file stem (with or without “.txt”)
      static func loadWorldDictionary(named stem: String) -> [String] {
          let (name, ext) = stem.lowercased().hasSuffix(".txt")
          ? (String(stem.dropLast(4)), "txt")
          : (stem, "txt")

          guard let url = Bundle.main.url(forResource: name, withExtension: ext),
                let raw = try? String(contentsOf: url)
          else { return [] }

          return raw
              .split(whereSeparator: \.isNewline)
              .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
              .filter { $0.count == 4 }
      }
}
