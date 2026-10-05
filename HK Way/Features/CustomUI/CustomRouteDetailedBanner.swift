//
//  CustomRouteDetailedBanner.swift
//  HK Way
//

import SwiftUI

struct CustomRouteDetailedBanner: View {
    @ScaledMetric(relativeTo: .title)
    private var routeNumberCharacterWidth: CGFloat = 20

    @ScaledMetric(relativeTo: .title)
    private var minimumRouteNumberWidth: CGFloat = 40

    @ScaledMetric(relativeTo: .title)
    private var maximumRouteNumberWidth: CGFloat = 84

    let routeNumber: String
    let origin: String
    let destination: String
    var routeBadgeColor: Color? = nil
    var routeBadgeTextColor: Color = .primary

    private var routeNumberWidth: CGFloat {
        min(
            max(
                CGFloat(routeNumber.count)
                    * routeNumberCharacterWidth,
                minimumRouteNumberWidth
            ),
            maximumRouteNumberWidth
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(routeNumber)
                .font(.title)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(width: routeNumberWidth)
                .foregroundStyle(routeBadgeTextColor)
                .padding(.horizontal, routeBadgeColor == nil ? 0 : 8)
                .padding(.vertical, routeBadgeColor == nil ? 0 : 6)
                .background {
                    if let routeBadgeColor {
                        Capsule().fill(routeBadgeColor)
                    }
                }
                .frame(
                    maxHeight: .infinity,
                    alignment: .center
                )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(origin)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Text(destination)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                .font(.headline)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .leading
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 84)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .customInfoCardSurface()
    }
}

#Preview {
    CustomRouteDetailedBanner(
        routeNumber: "948B",
        origin: "Greenfield Garden",
        destination: "Causeway Bay (Tin Hau)"
    )
    .padding()
    .background(.orange.opacity(0.12))
}
