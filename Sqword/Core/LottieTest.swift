//
//  LottieTest.swift
//  Sqword
//
//  Created by kevin nations on 10/12/25.
//

import SwiftUI

struct LottieTest: View {
    @State private var show = true
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if show {
                LottieView(name: "Dollar_Coins_Chest", loop: .playOnce, speed: 1.0) {
                    show = false
                }
                .frame(width: 240, height: 240)
            }
        }
    }
}
