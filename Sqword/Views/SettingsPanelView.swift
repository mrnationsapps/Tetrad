//
//  SettingsPanelView.swift
//  Sqword
//
//  Created by kevin nations on 10/25/25.
//
import SwiftUI

/// Shared settings panel (slide-up with scrim), reusable anywhere.
struct SettingsPanelView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var music: MusicCenter

    
    // Persisted settings you can read/write from anywhere
    @AppStorage("musicEnabled") private var musicEnabled: Bool = true
//    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {

            // CONTENT
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Settings").font(.headline)

                }

                // Music
                Toggle(isOn: $music.enabled) {
                    Label("Menu Music", systemImage: "music.note")
                }


//                // Haptics (wire this wherever you trigger haptics)
//                Toggle(isOn: $hapticsEnabled) {
//                    Label("Haptics", systemImage: "waveform")
//                }

                // …add more settings as needed
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120) // panel height
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .offset(x:0, y: 100)
    }
}


import SwiftUI

struct SettingsOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            // Scrim (tap to dismiss)
                            Color.black.opacity(0.25)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring()) { isPresented = false }
                                }

                            // Panel (sits above Home indicator)
                            SettingsPanelView(isPresented: $isPresented)
                                .padding(.bottom, geo.safeAreaInsets.bottom) // respect safe area
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .zIndex(1)
                        }
                        .ignoresSafeArea() // overlay only; doesn't shift layout
                    }
                    .zIndex(50) // above everything else
                }
            }
            .animation(.spring(), value: isPresented)
    }
}

extension View {
    func settingsOverlay(isPresented: Binding<Bool>) -> some View {
        self.modifier(SettingsOverlayModifier(isPresented: isPresented))
    }
}


