//
//  ResponsiveContainers.swift
//  Sqword
//
//  Created by kevin nations on 10/16/25.
//
import SwiftUI

/// A 4x4 square grid that grows to the largest square that fits the available space.
/// Each cell is sized identically (square).
struct ResponsiveBoard<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            // Board side = largest square that fits
            let side = min(geo.size.width, geo.size.height)
            // 4 cells → 3 gaps across. Compute per-cell edge length.
            let cell = floor((side - spacing * 3) / 4)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .center), count: 4),
                spacing: spacing
            ) {
                content()
                    .frame(width: cell, height: cell)      // ⬅️ force square wells/tiles
            }
            .environment(\.cellSize, cell)                 // ⬅️ let children scale fonts, etc.
            .frame(width: side, height: side)
            .position(x: geo.size.width/2, y: geo.size.height/2) // center the board
        }
    }
}

/// A responsive bag that wraps tiles with adaptive columns; tiles stay square.
struct ResponsiveBag<TileViewContent: View>: View {
    let tilesCount: Int
    let tileView: (_ index: Int) -> TileViewContent
    let spacing: CGFloat
    let minTile: CGFloat
    let maxTile: CGFloat

    init(tilesCount: Int,
         spacing: CGFloat = 8,
         minTile: CGFloat = 44,
         maxTile: CGFloat = 140,
         tileView: @escaping (_ index: Int) -> TileViewContent) {
        self.tilesCount = tilesCount
        self.spacing = spacing
        self.minTile = minTile
        self.maxTile = maxTile
        self.tileView = tileView
    }

    var body: some View {
        GeometryReader { geo in
            // Adaptive columns: SwiftUI picks as many as fit based on min/max.
            let cols = [GridItem(.adaptive(minimum: minTile, maximum: maxTile), spacing: spacing)]
            LazyVGrid(columns: cols, spacing: spacing) {
                ForEach(0..<tilesCount, id: \.self) { i in
                    tileView(i)
                        .frame(width: minTile, height: minTile) // ⬅️ keep square
                }
            }
            .frame(width: geo.size.width, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }
}

