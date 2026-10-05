//
//  CustomStopLineView.swift
//  HK Way
//
//  Created by Ken on 22/8/2026.
//

import SwiftUI

struct CustomStopLineView: View {

    @ScaledMetric(relativeTo: .caption)
    private var sequenceWidth: CGFloat = 24

    @ScaledMetric(relativeTo: .body)
    private var markerWidth: CGFloat = 16

    @ScaledMetric(relativeTo: .body)
    private var highlightedMarkerSize: CGFloat = 17

    @ScaledMetric(relativeTo: .body)
    private var regularMarkerSize: CGFloat = 12

    @ScaledMetric(relativeTo: .body)
    private var firstLineCenterY: CGFloat = 27

    @ScaledMetric(relativeTo: .caption)
    private var firstLineNumberTop: CGFloat = 19

    let sequence: Int
    let isFirst: Bool
    let isLast: Bool
    let operatorIds: [String]
    let isHighlighted: Bool
    let routeColor: Color?
    let markerAtFirstLine: Bool

    init(
        sequence: Int,
        isFirst: Bool = false,
        isLast: Bool = false,
        operatorIds: [String] = [],
        isHighlighted: Bool = false,
        routeColor: Color? = nil,
        markerAtFirstLine: Bool = false
    ) {
        self.sequence = sequence
        self.isFirst = isFirst
        self.isLast = isLast
        self.operatorIds = operatorIds
        self.isHighlighted = isHighlighted
        self.routeColor = routeColor
        self.markerAtFirstLine = markerAtFirstLine
    }

    private var lineStyle: AnyShapeStyle {
        if let routeColor { return AnyShapeStyle(routeColor) }
        let colors = operatorIds
            .prefix(2)
            .map {
                CustomBadgeView.backgroundColor(for: $0)
            }

        guard let firstColor = colors.first else {
            return AnyShapeStyle(Color.accentColor)
        }

        guard colors.count > 1 else {
            return AnyShapeStyle(firstColor)
        }

        let ids = Set(operatorIds)

        if ids.contains("KMB") && ids.contains("CTB") {
            return AnyShapeStyle(Color.orange)
        }

        if ids.contains("LWB") && ids.contains("CTB") {
            return AnyShapeStyle(
                Color(
                    red: 0.98,
                    green: 0.64,
                    blue: 0.04
                )
            )
        }

        return AnyShapeStyle(firstColor)
    }

    var body: some View {

        HStack(
            alignment: markerAtFirstLine ? .top : .center,
            spacing: 8
        ) {

            Text("\(sequence)")
                .font(.caption)
                .fontWeight(
                    isHighlighted
                    ? .bold
                    : .regular
                )
                .foregroundStyle(
                    isHighlighted
                    ? .primary
                    : .secondary
                )
                .monospacedDigit()
                .frame(
                    width: sequenceWidth,
                    alignment: .trailing
                )
                .padding(.top, markerAtFirstLine ? firstLineNumberTop : 0)

            GeometryReader { geometry in

                let centerX =
                    geometry.size.width / 2

                let centerY = markerAtFirstLine
                    ? firstLineCenterY
                    : geometry.size.height / 2

                Path { path in

                    if !isFirst {
                        path.move(
                            to: CGPoint(
                                x: centerX,
                                y: 0
                            )
                        )
                        path.addLine(
                            to: CGPoint(
                                x: centerX,
                                y: centerY
                            )
                        )
                    }

                    if !isLast {
                        path.move(
                            to: CGPoint(
                                x: centerX,
                                y: centerY
                            )
                        )
                        path.addLine(
                            to: CGPoint(
                                x: centerX,
                                y: geometry.size.height
                            )
                        )
                    }
                }
                .stroke(
                    lineStyle,
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round
                    )
                )

                Circle()
                    .fill(
                        isHighlighted
                            ? lineStyle
                            : AnyShapeStyle(
                                Color(
                                    uiColor: .systemBackground
                                )
                            )
                    )
                    .stroke(
                        lineStyle,
                        lineWidth: 3
                    )
                    .frame(
                        width: isHighlighted
                            ? highlightedMarkerSize
                            : regularMarkerSize,
                        height: isHighlighted
                            ? highlightedMarkerSize
                            : regularMarkerSize
                    )
                    .position(
                        x: centerX,
                        y: centerY
                    )
            }
            .frame(width: markerWidth)
        }
        .frame(
            width: sequenceWidth + markerWidth + 8,
            alignment: .leading
        )
        .frame(maxHeight: .infinity)
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            "Stop \(sequence)"
        )
    }
}

#Preview {
    VStack(spacing: 0) {
        CustomStopLineView(
            sequence: 1,
            isFirst: true
        )
        CustomStopLineView(sequence: 2)
        CustomStopLineView(
            sequence: 3,
            isLast: true
        )
    }
    .frame(height: 180)
    .padding()
}
