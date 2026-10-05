//
//  MessageBubbleView.swift
//  HK Way
//
//  Created by Ken on 14/8/2026.
//

import SwiftUI

struct CustomCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentFrame = 0
    @State private var isAnimating = false

    let imageIcon: String
    let title: String
    let subTitle: String
    let animated: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if animated {
                    HStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { index in
                            if index == currentFrame {
                                Image(systemName: imageIcon)
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tint)
                                    .frame(width: 30, height: 30)
                                    .transition(
                                        .scale.combined(with: .opacity)
                                    )
                            } else {
                                Circle()
                                    .fill(Color.secondary.opacity(0.4))
                                    .frame(width: 10, height: 10)
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }
                    .frame(height: 48)
                    .animation(
                        .easeInOut(duration: 0.5),
                        value: currentFrame
                    )
                    .task {
                        while !Task.isCancelled {
                            do {
                                try await Task.sleep(
                                    for: .seconds(0.6)
                                )
                            } catch {
                                return
                            }

                            currentFrame = (currentFrame + 1) % 5
                        }
                    }
                } else {
                    Image(systemName: imageIcon)
                        .font(.system(size: 32))
                        .foregroundStyle(.tint)
                        .offset(
                            y: isAnimating
                                ? -12
                                : 12
                        )
                        .scaleEffect(
                            isAnimating
                                ? 1.20
                                : 1.0
                        )
                        .frame(height: 48)
                        .task {
                            guard !isAnimating else {
                                return
                            }

                            await Task.yield()

                            withAnimation(
                                .easeInOut(duration: 0.9)
                                    .repeatForever(
                                        autoreverses: true
                                    )
                            ) {
                                isAnimating = true
                            }
                        }
                }

                Text(LocalizedStringKey(title))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text(LocalizedStringKey(subTitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                colorScheme == .dark
                    ? Color(uiColor: .systemGray6)
                    : .white
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: .black.opacity(0.3),
                radius: 16,
                x: 0,
                y: 8
            )
        }
    }
}

#Preview {
    CustomCardView(
        imageIcon: "bus.fill",
        title: "Loading",
        subTitle: "Please wait...",
        animated: true
    )
}
