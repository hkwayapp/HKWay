//
//  CustomRouteKeyboardView.swift
//  HK Way
//

import SwiftUI
import UIKit

struct CustomRouteKeyboardView: View {

    private static let hapticGenerator =
        UIImpactFeedbackGenerator(style: .heavy)

    @Binding
    var text: String

    var enabledKeys: Set<String>? = nil

    private let numberRows = [
        ["1", "2", "3", "4", "5"],
        ["6", "7", "8", "9", "0"]
    ]

    private let letters =
        Array("ABCDEFGHKMNPRSTWX")
            .map(String.init)

    var body: some View {

        VStack(spacing: 10) {

            HStack(spacing: 10) {

                Text(
                    text.isEmpty
                    ? "Route"
                    : text
                )
                .font(.headline)
                .foregroundStyle(
                    text.isEmpty
                    ? Color.secondary
                    : Color.primary
                )
                .lineLimit(1)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

                Button("Clear") {
                    playHapticFeedback()
                    text = ""
                }
                .buttonStyle(
                    RouteKeyboardControlStyle()
                )
                .disabled(text.isEmpty)

                Button {
                    guard !text.isEmpty else {
                        return
                    }

                    playHapticFeedback()
                    text.removeLast()

                } label: {

                    Label(
                        "Delete",
                        systemImage:
                            "delete.backward.fill"
                    )
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(
                    RouteKeyboardControlStyle()
                )
                .disabled(text.isEmpty)
            }

            ForEach(
                numberRows,
                id: \.self
            ) { row in

                HStack(spacing: 8) {

                    ForEach(
                        row,
                        id: \.self
                    ) { key in

                        keyButton(key)
                    }
                }
            }

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {

                HStack(spacing: 8) {

                    ForEach(
                        availableLetters,
                        id: \.self
                    ) { key in

                        keyButton(
                            key,
                            fixedWidth: 48,
                            keyColor:
                                Color(.systemGray4)
                        )
                    }
                }
                .padding(.horizontal, 1)
            }
            .frame(height: 48)
        }
        .padding(12)
        .background(
            Color(.systemGray5)
        )
    }

    private func keyButton(
        _ key: String,
        fixedWidth: CGFloat? = nil,
        keyColor: Color =
            Color(.systemBackground)
    ) -> some View {

        Button {
            playHapticFeedback()
            text.append(key)
        } label: {
            Text(key)
                .font(
                    key.allSatisfy { $0.isNumber }
                        ? .title.bold()
                        : .title3.bold()
                )
                .frame(
                    maxWidth:
                        fixedWidth == nil
                        ? .infinity
                        : nil,
                    minHeight: 48
                )
                .frame(width: fixedWidth)
                .background(keyColor)
                .clipShape(
                    RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: 8)
                )
                .opacity(
                    isKeyEnabled(key)
                    ? 1
                    : 0.3
                )
        }
        .disabled(!isKeyEnabled(key))
        .buttonStyle(.plain)
        .accessibilityLabel(key)
    }

    private func isKeyEnabled(
        _ key: String
    ) -> Bool {

        enabledKeys?.contains(key) ?? true
    }

    private func playHapticFeedback() {
        Self.hapticGenerator.prepare()
        Self.hapticGenerator.impactOccurred()
    }

    private var availableLetters: [String] {

        guard let enabledKeys else {
            return letters
        }

        return letters.filter {
            enabledKeys.contains($0)
        }
    }
}

private struct RouteKeyboardControlStyle:
    ButtonStyle {

    func makeBody(
        configuration: Configuration
    ) -> some View {

        configuration.label
            .font(.headline)
            .frame(
                minWidth: 56,
                minHeight: 42
            )
            .background(
                Color(.systemBackground)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .opacity(
                configuration.isPressed
                ? 0.6
                : 1
            )
    }
}

#Preview {

    @Previewable
    @State var text = "1A"

    CustomRouteKeyboardView(
        text: $text
    )
}
