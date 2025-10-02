//
//  Worlds.swift
//  Tetrad
//
//  Created by kevin nations on 9/28/25.
//

import Foundation

struct World: Identifiable, Codable, Equatable {
    let id: String                 // "tutorial", "food", etc.
    let name: String               // "Tutorial", "Food"
    let artName: String?           // asset name for the card (optional for now)
    let unlockCost: Int            // coins required to unlock (0 for tutorial)
    let dictionaryID: String       // which word list to use
    let isTutorial: Bool           // true only for tutorial
}

enum WorldsCatalog {
    static let all: [World] = [
        World(id: "tutorial",
              name: "Tutorial",
              artName: "WorldCard_Tutorial",
              unlockCost: 0,
              dictionaryID: "Adjectives_Dictionary",   // or your own tutorial list
              isTutorial: true),

        World(id: "food",
              name: "Food",
              artName: "WorldCard_Food",
              unlockCost: 10,
              dictionaryID: "Food_Drink_Dictionary",
              isTutorial: false),

        World(id: "animals",
              name: "Animals",
              artName: "WorldCard_Animals",
              unlockCost: 12,
              dictionaryID: "Animals_Dictionary",
              isTutorial: false),

        World(id: "nature",
              name: "Nature",
              artName: "WorldCard_Nature",
              unlockCost: 12,
              dictionaryID: "Plants_Dictionary",       // ← matches your file list
              isTutorial: false),

        World(id: "holidays",
              name: "Holidays",
              artName: "WorldCard_Holidays",
              unlockCost: 14,
              dictionaryID: "Places_Dictionary",       // temp until you add Holidays_Dictionary.txt
              isTutorial: false),

        World(id: "retro",
              name: "Retro",
              artName: "WorldCard_Retro",
              unlockCost: 14,
              dictionaryID: "Adjectives_Dictionary",   // pick a file to use for now
              isTutorial: false),

        World(id: "travel",
              name: "Travel",
              artName: "WorldCard_Travel",
              unlockCost: 16,
              dictionaryID: "Places_Dictionary",
              isTutorial: false),

        World(id: "history",
              name: "History",
              artName: "WorldCard_History",
              unlockCost: 16,
              dictionaryID: "History_Dictionary",
              isTutorial: false),

        World(id: "entertainment",
              name: "Entertainment",
              artName: "WorldCard_Entertainment",
              unlockCost: 18,
              dictionaryID: "Arts_Entertainment_Dictionary",
              isTutorial: false)
    ]
}

