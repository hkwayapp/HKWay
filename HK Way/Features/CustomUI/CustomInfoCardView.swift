//
//  CustomInfoCardView.swift
//  HK Way
//
//  Created by Ken on 22/8/2026.
//

import SwiftUI

struct CustomInfoCardView<Content: View>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 6) {
            if !title.isEmpty {
                Text(LocalizedStringKey(title))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            content
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 84)
        .customInfoCardSurface()
    }
}

extension CustomInfoCardView
where Content == CustomInfoCardMessageView {
    init(title: String, message: String) {
        self.init(title: title) {
            CustomInfoCardMessageView(
                message: message
            )
        }
    }
}

struct CustomInfoCardMessageView: View {
    let message: String

    var body: some View {
        Text(LocalizedStringKey(message))
            .font(.title2)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .minimumScaleFactor(0.75)
            .lineLimit(2)
    }
}

#Preview {
    CustomInfoCardView(
        title: "Route Number",
        message: "1"
    )
}
