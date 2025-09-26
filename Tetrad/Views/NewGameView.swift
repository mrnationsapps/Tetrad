//
//  NewGameView.swift
//  Tetrad
//
//  Created by kevin nations on 9/10/25.
//
import SwiftUI

struct PlayerProfile: Codable {
    var name: String
    var avatarIndex: Int // 1…12
    var totalCoins: Int

    static func load() -> PlayerProfile {
        let d = UserDefaults.standard
        let name = d.string(forKey: "player_name") ?? "Player"
        let idx  = d.integer(forKey: "player_avatarIndex")
        return PlayerProfile(name: name, avatarIndex: max(1, idx), totalCoins: 0)
    }
    func save() {
        let d = UserDefaults.standard
        d.set(name, forKey: "player_name")
        d.set(avatarIndex, forKey: "player_avatarIndex")
    }
}

struct NewGameView: View {
    @State private var name: String
    @State private var avatarIndex: Int

    let onGo: (_ profile: PlayerProfile) -> Void
    let onBack: () -> Void   // 👈 added

    init(
        profile: PlayerProfile,
        onGo: @escaping (PlayerProfile) -> Void,
        onBack: @escaping () -> Void
    ) {
        _name = State(initialValue: profile.name)
        _avatarIndex = State(initialValue: profile.avatarIndex == 0 ? 1 : profile.avatarIndex)
        self.onGo = onGo
        self.onBack = onBack
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 16) {

                    Text("Your Avatar")
                        .font(.title2).bold()

                    // 4x3 avatar grid
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(1...12, id: \.self) { i in
                            let selected = (i == avatarIndex)
                            Image(String(format: "Avatar-%02d", i))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(selected ? Color.blue : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture { avatarIndex = i }
                                .accessibilityLabel(selected ? "Avatar \(i), selected" : "Avatar \(i)")
                        }
                    }
                    .padding(.horizontal)

                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name").font(.headline)
                        TextField("Enter name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                    }
                    .padding(.horizontal)

                    // PREVIEW — large avatar + name, centered
                    VStack(spacing: 10) {
                        Image(String(format: "Avatar-%02d", avatarIndex))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.blue.opacity(0.4), lineWidth: 4)
                            )
                            .shadow(radius: 6, x: 0, y: 2)

                        Text(previewName)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 8)

                    // Go button
                    Button {
                        let p = PlayerProfile(name: finalName, avatarIndex: avatarIndex, totalCoins: 0)
                        p.save()
                        onGo(p)
                    } label: {
                        Text("Go!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .padding(.top, 16)
            }

            // Always-visible Back button (top-left)
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.headline)
                    Text("Back").font(.headline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5))
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .padding(.top, 12)
            .padding(.leading, 12)
        }
        // Optional, keeps the button visible when keyboard is up
        //.ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Helpers

    private var finalName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Player" : trimmed
    }

    private var previewName: String {
        finalName
    }
}
