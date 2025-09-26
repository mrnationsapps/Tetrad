import Foundation

struct BoardCoord: Hashable, Codable {
    let row: Int
    let col: Int
}

enum TileLocation: Codable, Equatable, Hashable {
    case bag
    case board(BoardCoord)
}

struct LetterTile: Identifiable, Hashable {  
    let id: UUID
    let letter: Character
    var hasBeenPlacedOnce: Bool
    var location: TileLocation

    init(letter: Character, location: TileLocation = .bag) {
        self.id = UUID()
        self.letter = letter
        self.hasBeenPlacedOnce = false
        self.location = location
    }
}
