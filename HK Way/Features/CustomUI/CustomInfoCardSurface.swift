//
//  CustomInfoCardSurface.swift
//  HK Way
//

import SwiftUI

private struct CustomInfoCardSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let showsShadow: Bool

    private var cardColor: Color {
        colorScheme == .dark
            ? Color(uiColor: .secondarySystemBackground)
            : .white
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.18)
            : .black.opacity(0.12)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? .black.opacity(0.4)
            : .black.opacity(0.18)
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(cardColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(
                color: showsShadow
                    ? shadowColor
                    : .clear,
                radius: showsShadow
                    ? (colorScheme == .dark ? 8 : 12)
                    : 0,
                x: 0,
                y: showsShadow
                    ? (colorScheme == .dark ? 4 : 7)
                    : 0
            )
    }
}

extension View {
    func customInfoCardSurface(
        cornerRadius: CGFloat = 18,
        showsShadow: Bool = true
    ) -> some View {
        modifier(
            CustomInfoCardSurface(
                cornerRadius: cornerRadius,
                showsShadow: showsShadow
            )
        )
    }
}
