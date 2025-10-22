//
//  TitleView.swift
//  Sqword
//
//  Created by kevin nations on 9/26/25.
//

import SwiftUI

struct TitleView: View {
    var onFinish: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("Sqword-Splash")
                .resizable()
                .scaledToFill()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appear = true }
        }
        
        .overlay {
            Image("Sqword-title")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 560)     // cap for iPad Pro etc.
                .padding(.horizontal, 80) // keeps it off the edges on phones
                .offset(y: -100)       // pushes overlay down from center
        }
        
        .overlay(alignment: .bottom) {
            Button(action: onFinish) {
                Text("Continue")
                    .font(.title3).bold()
                    .foregroundStyle(.primary)
            }
            .buttonStyle(SoftRaisedPillStyle(height: 52))
            .padding(.bottom, 80)
            .frame(width: 200)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
