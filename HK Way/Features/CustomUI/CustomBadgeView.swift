//
//  CustomBadgeView.swift
//  HK Way
//
//  Created by Ken on 14/8/2026.
//

import SwiftUI

struct CustomBadgeView: View {
    @Environment(\.transitLanguage)
    private var transitLanguage

    let text: String
    let operatorId: String?
    let backgroundColor: Color
    let textColor: Color
    let isCompact: Bool
    let fontSize: CGFloat?

    init(
        text: String,
        backgroundColor: Color,
        textColor: Color = .white,
        isCompact: Bool = false,
        fontSize: CGFloat? = nil
    ) {
        self.text = text
        self.operatorId = nil
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.isCompact = isCompact
        self.fontSize = fontSize
    }

    init(
        operatorId: String,
        isCompact: Bool = false,
        fontSize: CGFloat? = nil
    ) {
        self.text = Self.displayText(for: operatorId)
        self.operatorId = operatorId
        self.backgroundColor = Self.backgroundColor(for: operatorId)
        self.textColor = Self.textColor(for: operatorId)
        self.isCompact = isCompact
        self.fontSize = fontSize
    }

    static func displayText(
        for operatorId: String
    ) -> String {
        return operatorId == "LRTFeeder"
            ? "MTR"
            : operatorId
    }

    static func displayText(
        for operatorId: String,
        language: TransitLanguage
    ) -> String {
        guard language != .english else {
            return displayText(for: operatorId)
        }

        let chineseNames: [String: String]
        switch language {
        case .simplifiedChinese:
            chineseNames = [
                "KMB": "九巴", "LWB": "龙运", "CTB": "城巴",
                "NLB": "屿巴", "GMB": "专线小巴", "LRTFeeder": "港铁",
                "PI": "居民巴士", "DB": "愉景湾", "XB": "过境巴士",
                "TRAM": "香港电车"
            ]
        case .traditionalChinese:
            chineseNames = [
                "KMB": "九巴", "LWB": "龍運", "CTB": "城巴",
                "NLB": "嶼巴", "GMB": "專線小巴", "LRTFeeder": "港鐵",
                "PI": "居民巴士", "DB": "愉景灣", "XB": "過境巴士",
                "TRAM": "香港電車"
            ]
        case .english:
            chineseNames = [:]
        }

        return chineseNames[operatorId]
            ?? displayText(for: operatorId)
    }

    static func backgroundColor(
        for operatorId: String
    ) -> Color {
        switch operatorId {
        case "KMB":
            .red
        case "LWB":
            Color(
                red: 0.95,
                green: 0.45,
                blue: 0.08
            )
        case "CTB":
            Color(
                red: 1,
                green: 0.82,
                blue: 0
            )
        case "NLB":
            Color(
                red: 0.35,
                green: 0.75,
                blue: 0.95
            )
        case "GMB":
            .green
        case "LRTFeeder":
            Color(
                red: 0.15,
                green: 0.32,
                blue: 0.62
            )
        case "PI":
            .teal
        case "DB":
            .purple
        case "XB":
            .gray
        case "TRAM":
            Color(
                red: 0.08,
                green: 0.43,
                blue: 0.24
            )
        default:
            .gray
        }
    }

    static func textColor(
        for operatorId: String
    ) -> Color {
        switch operatorId {
        case "CTB", "NLB":
            .black
        default:
            .white
        }
    }

    private var badgeFont: Font {
        if let fontSize {
            return .system(size: fontSize)
        }

        return isCompact
            ? .system(size: 10)
            : .caption
    }

    var body: some View {
        Text(
            operatorId.map {
                Self.displayText(
                    for: $0,
                    language: transitLanguage
                )
            } ?? text
        )
            .font(badgeFont)
            .fontWeight(.semibold)
            .frame(minWidth: isCompact ? 30 : 35)
            .padding(.horizontal, isCompact ? 8 : 12)
            .padding(.vertical, isCompact ? 4 : 6)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 16) {
        CustomBadgeView(operatorId: "KMB")
        CustomBadgeView(operatorId: "CTB")
        CustomBadgeView(operatorId: "NLB")
    }
    .padding()
}
