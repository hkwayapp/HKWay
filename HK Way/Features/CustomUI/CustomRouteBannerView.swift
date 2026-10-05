//
//  CustomRouteBannerView.swift
//  HK Way
//

import SwiftUI

struct CustomRouteBannerView: View {
    @ScaledMetric(relativeTo: .title)
    private var routeNumberCharacterWidth: CGFloat = 20

    let routeNumber: String?
    let origin: String
    let destination: String

    init(
        routeNumber: String? = nil,
        origin: String,
        destination: String
    ) {
        self.routeNumber = routeNumber
        self.origin = origin
        self.destination = destination
    }

    var body: some View {
        HStack(spacing: 12) {
            if let routeNumber {
                Text(routeNumber)
                    .font(.title)
                    .fontWeight(.semibold) 
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(
                        width: min(
                            max(
                                CGFloat(routeNumber.count)
                                    * routeNumberCharacterWidth,
                                40
                            ),
                            84
                        )
                    )
            }

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(origin)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Text(destination)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .customInfoCardSurface(
            showsShadow: false
        )
    }
}

#Preview {
    CustomRouteBannerView(
        routeNumber: "948B",
        origin: "Greenfield Garden",
        destination: "Tin Hau Station"
    )
    .padding()
}
