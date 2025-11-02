//
//  Worlds.swift
//  Sqword
//
//  Created by kevin nations on 9/28/25.
//

import Foundation
import SwiftUI

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
              artName: "Tutorial",
              unlockCost: 0,
              dictionaryID: "Adjectives_Dictionary",
              isTutorial: true),

        World(id: "food",
              name: "Food",
              artName: "Food",
              unlockCost: 6,
              dictionaryID: "Food_Drink_Dictionary",
              isTutorial: false),

        World(id: "animals",
              name: "Animals",
              artName: "Animals",
              unlockCost: 25,
              dictionaryID: "Animals_Dictionary",
              isTutorial: false),

        World(id: "nature",
              name: "Nature",
              artName: "Nature",
              unlockCost: 40,
              dictionaryID: "Plants_Dictionary",
              isTutorial: false),

        World(id: "holidays",
              name: "Holidays",
              artName: "Holiday",
              unlockCost: 150,
              dictionaryID: "Holiday_Dictionary",
              isTutorial: false),

        World(id: "tech",
              name: "Technology",
              artName: "Retro",
              unlockCost: 30,
              dictionaryID: "Technology_Dictionary",
              isTutorial: false),

        World(id: "travel",
              name: "Places",
              artName: "Places",
              unlockCost: 100,
              dictionaryID: "Places_Dictionary",
              isTutorial: false),

        World(id: "history",
              name: "History",
              artName: "History",
              unlockCost: 125,
              dictionaryID: "History_Dictionary",
              isTutorial: false),

        World(id: "entertainment",
              name: "Entertainment",
              artName: "Entertainment",
              unlockCost: 150,
              dictionaryID: "Arts_Entertainment_Dictionary",
              isTutorial: false)
    ]
}

// MARK: - Boosts panel for Worlds (read-only; tells user to open a level)
struct WorldsBoostsPanel: View {
    @EnvironmentObject var boosts: BoostsService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Label("Boosts", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                // Purchased-only model: show how many the player owns
                Text("\(boosts.purchased) owned")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 12) {
                // Show the tile but disable using it from Worlds
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.thinMaterial)
                        .frame(width: 88, height: 88)
                        .overlay(
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 28, weight: .semibold))
                        )
                    Text("Reveal")
                        .font(.footnote.weight(.semibold))
                }
                .opacity(0.45)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Reveals can only be used while playing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Open any level to use a Boost.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}



// MARK: - Wallet panel for Worlds (buy boosts + coins)
struct WorldsWalletPanel: View {
    @EnvironmentObject var levels: LevelsService
    @EnvironmentObject var boosts: BoostsService
    @EnvironmentObject var game: GameState      // ← added so we can tick achievements

    var dismiss: () -> Void

    @State private var showInsufficientCoins = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Wallet", systemImage: "creditcard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill").imageScale(.large)
                    Text("\(levels.coins)").font(.headline).monospacedDigit()
                }
                .softRaisedCapsule()
            }

            // Buy Boosts
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Buy Boosts").font(.subheadline).foregroundStyle(.secondary)
//                HStack(spacing: 10) {
//                    walletBoostPill(icon: "wand.and.stars", title: "Reveal ×1",  cost: 5)  { buyReveal(cost: 5,  count: 1) }
//                    walletBoostPill(icon: "wand.and.stars", title: "Reveal ×3",  cost: 12) { buyReveal(cost: 12, count: 3) }
//                    walletBoostPill(icon: "wand.and.stars", title: "Reveal ×10", cost: 35) { buyReveal(cost: 35, count: 10) }
//                }
//            }

            // Get Coins (IAP stubs)
            VStack(alignment: .leading, spacing: 8) {
                Text("Get Coins").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    walletIAPPill(amount: 100,  price: "$0.99") { addCoins(100) }
                    walletIAPPill(amount: 300,  price: "$2.99") { addCoins(300) }
                    walletIAPPill(amount: 1200, price: "$7.99") { addCoins(1200) }
                }
            }
        }
        .alert("Not enough coins", isPresented: $showInsufficientCoins) {
            Button("OK", role: .cancel) { }
        } message: { Text("You don't have enough coins for that purchase.") }
    }

    // MARK: actions
    private func buyReveal(cost: Int, count: Int) {
        // Centralized buy: deduct coins + add to purchased pool (persists)
        if levels.buyBoost(cost: cost, count: count, boosts: boosts, haptics: true) {
            // If the app hasn't wired BoostsService.onBoostPurchased -> GameState,
            // tick the achievement counter here to be safe (avoid double-counting).
            if boosts.onBoostPurchased == nil {
                game.noteBoostPurchased(count: count)
            }
            dismiss()
        } else {
            showInsufficientCoins = true
        }
    }

    private func addCoins(_ n: Int) {
        levels.addCoins(n)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        dismiss()
    }

    // MARK: tiny pills (local copies so we don't depend on private funcs elsewhere)
    @ViewBuilder
    private func walletBoostPill(icon: String, title: String, cost: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill").imageScale(.small)
                    Text("\(cost)").font(.caption2).monospacedDigit()
                }.opacity(0.9)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func walletIAPPill(amount: Int, price: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill").imageScale(.small)
                    Text("+\(amount)").font(.caption).monospacedDigit()
                }
                Text(price).font(.caption2).opacity(0.9)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
