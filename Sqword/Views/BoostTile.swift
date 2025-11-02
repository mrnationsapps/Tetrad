//
//  BoostTile.swift
//  Sqword
//
//  Created by kevin nations on 11/1/25.
//

import SwiftUI

public struct BoostTile: View {
    public enum Style {
        /// Compact panel chip (what you used in ContentView’s boosts panel)
        case panelChip
        /// Square card (what you used in LevelPlayView/TutorialWorldView)
        case squareCard(width: CGFloat = 88, height: CGFloat = 88, corner: CGFloat = 14)
    }

    let icon: String
    let title: String
    let style: Style
    /// Optional count badge (top-right). Pass nil to hide.
    let count: Int?
    /// Optional background material for square cards.
    let material: Material?

    public init(
        icon: String,
        title: String,
        style: Style = .panelChip,
        count: Int? = nil,
        material: Material? = nil
    ) {
        self.icon = icon
        self.title = title
        self.style = style
        self.count = count
        self.material = material
    }

    public var body: some View {
        switch style {
        case .panelChip:
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Image(systemName: icon).font(.headline)
                    Text(title).font(.caption)
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        )
                )

                if let c = count, c > 0 {
                    CountBadge(count: c).offset(x: 6, y: -6)
                }
            }

        case .squareCard(let w, let h, let r):
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(material ?? .ultraThinMaterial)
                            .frame(width: w, height: h)
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                if let c = count, c > 0 {
                    CountBadge(count: c).offset(x: 6, y: -6)
                }
            }
        }
    }
}

private struct CountBadge: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThickMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
            .shadow(radius: 2, y: 1)
            .accessibilityLabel(Text("\(count) available"))
    }
}
