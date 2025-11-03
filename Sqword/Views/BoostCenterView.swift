import SwiftUI

struct BoostCenterView: View {
    @EnvironmentObject var boosts: BoostsService
    @EnvironmentObject var game: GameState

    @Environment(\.dismiss) private var dismiss
    @State private var confirmSmartBoost = false
    @State private var errorText: String?


    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Boosts")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(boosts.totalAvailable) available")
                                .foregroundStyle(.secondary)
                            Text("(\(boosts.purchased) purchased • \(boosts.remaining) daily)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Available Boosts") {
                    Button {
                        confirmSmartBoost = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "wand.and.stars")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Smart Boost")
                                    .font(.headline)
                                Text("Auto-place one correct tile. Costs +10 moves.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    // ✅ Do not gate on `remaining` — purchased must work
                    .disabled(boosts.totalAvailable == 0)
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Boosts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Use Smart Boost?",
                isPresented: $confirmSmartBoost,
                titleVisibility: .visible
            ) {
                Button("Use Boost (adds +10 moves)") { useSmartBoost() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will place 1 correct tile and add +10 to your Moves.")
            }
            // Clear any stale error when dialog visibility changes
            .onChange(of: confirmSmartBoost) { _, _ in errorText = nil }
        }
    }

    private func useSmartBoost() {
        // spend REVEAL
        guard boosts.count(for: .reveal) > 0 else {
            errorText = "No Boosts left."
            return
        }
        if game.applySmartBoost(movePenalty: 10) {
            _ = boosts.useOne(kind: .reveal)
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            dismiss()
        } else {
            errorText = "No safe placement found. Try adjusting the board first."
        }
    }
    
    private func useClarityBoost() {
        // Check if in level mode (World levels only)
        guard game.isLevelMode else {
            errorText = "Clarity only works in World levels."
            return
        }
        
        // Check if boosts available
        guard boosts.count(for: .clarity) > 0 else {
            errorText = "No Clarity boosts left."
            return
        }
        
        // Apply the boost
        if game.applyClarityBoost() {
            _ = boosts.useOne(kind: .clarity)
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            dismiss()
        } else {
            errorText = "Nothing to highlight right now."
        }
    }
}
