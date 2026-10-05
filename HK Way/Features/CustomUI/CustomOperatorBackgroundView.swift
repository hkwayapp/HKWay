//
//  CustomOperatorBackgroundView.swift
//  HK Way
//

import SwiftUI

struct CustomOperatorBackgroundView: View {
    let operatorIds: [String]

    private var colors: [Color] {
        let operatorColors = operatorIds
            .prefix(2)
            .map {
                CustomBadgeView
                    .backgroundColor(for: $0)
                    .opacity(0.12)
            }

        guard let firstColor = operatorColors.first else {
            return [.clear, .clear]
        }

        return operatorColors.count == 1
            ? [firstColor, firstColor]
            : Array(operatorColors)
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    CustomOperatorBackgroundView(
        operatorIds: ["KMB", "CTB"]
    )
}
