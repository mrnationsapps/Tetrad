//
//  BoardFrameReporting.swift
//  Tetrad
//
//  Created by kevin nations on 10/3/25.
//

import SwiftUI

struct BoardFrameKey: PreferenceKey {
    static var defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

/// Emits the view’s frame in .global coordinates via BoardFrameKey
struct BoardFrameReporter: View {
    var body: some View {
        GeometryReader { g in
            Color.clear
                .preference(key: BoardFrameKey.self, value: g.frame(in: .global))
        }
    }
}
