import SwiftUI
import SwiftData

private struct RegularSightseeingConnection: Identifiable {
    let id: String
    let numbers: [String]
    let operatorID: String
    let englishTitle: String
    let traditionalTitle: String
    let simplifiedTitle: String
    let englishCoverage: String
    let traditionalCoverage: String
    let simplifiedCoverage: String

    func title(for language: TransitLanguage) -> String {
        switch language {
        case .english: englishTitle
        case .traditionalChinese: traditionalTitle
        case .simplifiedChinese: simplifiedTitle
        }
    }

    func coverage(for language: TransitLanguage) -> String {
        switch language {
        case .english: englishCoverage
        case .traditionalChinese: traditionalCoverage
        case .simplifiedChinese: simplifiedCoverage
        }
    }

    static let all: [Self] = [
        .init(id: "kmb-1a", numbers: ["1A"], operatorID: "KMB", englishTitle: "KMB 1A", traditionalTitle: "九巴 1A", simplifiedTitle: "九巴 1A", englishCoverage: "Kwun Tong · Mong Kok · Nathan Road · Tsim Sha Tsui", traditionalCoverage: "觀塘 · 旺角 · 彌敦道 · 尖沙咀", simplifiedCoverage: "观塘 · 旺角 · 弥敦道 · 尖沙咀"),
        .init(id: "ctb-15", numbers: ["15"], operatorID: "CTB", englishTitle: "Citybus 15 · Peak Explorer", traditionalTitle: "城巴 15 · 山頂探索者", simplifiedTitle: "城巴 15 · 山顶探索者", englishCoverage: "Central · Admiralty · Wan Chai · The Peak", traditionalCoverage: "中環 · 金鐘 · 灣仔 · 山頂", simplifiedCoverage: "中环 · 金钟 · 湾仔 · 山顶"),
        .init(id: "ctb-6", numbers: ["6", "6X"], operatorID: "CTB", englishTitle: "Citybus 6 / 6X · Scenic Summit", traditionalTitle: "城巴 6 / 6X · 赤柱海岸線", simplifiedTitle: "城巴 6 / 6X · 赤柱海岸线", englishCoverage: "Central · Repulse Bay · Stanley", traditionalCoverage: "中環 · 淺水灣 · 赤柱", simplifiedCoverage: "中环 · 浅水湾 · 赤柱"),
        .init(id: "ctb-973", numbers: ["973"], operatorID: "CTB", englishTitle: "Citybus 973", traditionalTitle: "城巴 973", simplifiedTitle: "城巴 973", englishCoverage: "Tsim Sha Tsui · West Kowloon · Aberdeen · Repulse Bay · Stanley", traditionalCoverage: "尖沙咀 · 西九龍 · 香港仔 · 淺水灣 · 赤柱", simplifiedCoverage: "尖沙咀 · 西九龙 · 香港仔 · 浅水湾 · 赤柱"),
        .init(id: "nlb-11", numbers: ["11"], operatorID: "NLB", englishTitle: "New Lantao Bus 11", traditionalTitle: "新大嶼山巴士 11", simplifiedTitle: "新大屿山巴士 11", englishCoverage: "Tung Chung · South Lantau · Tai O", traditionalCoverage: "東涌 · 南大嶼山 · 大澳", simplifiedCoverage: "东涌 · 南大屿山 · 大澳")
    ]
}

private struct SightseeingRoute: Identifiable {
    enum Operator: String, CaseIterable, Identifiable {
        case citybus
        case kmb

        var id: String { rawValue }

        func name(for language: TransitLanguage) -> String {
            switch (self, language) {
            case (.citybus, .english): "Citybus · HK City Sightseeing"
            case (.citybus, _): "城巴 · 觀光城巴"
            case (.kmb, .english): "KMB TOUR HK"
            case (.kmb, _): "九巴遊香港"
            }
        }
    }

    let number: String
    let routeOperator: Operator
    let englishName: String
    let traditionalName: String
    let simplifiedName: String
    let englishHighlights: String
    let traditionalHighlights: String
    let simplifiedHighlights: String
    let officialURL: URL

    var id: String { "\(routeOperator.rawValue)-\(number)" }

    func name(for language: TransitLanguage) -> String {
        switch language {
        case .english: englishName
        case .traditionalChinese: traditionalName
        case .simplifiedChinese: simplifiedName
        }
    }

    func highlights(for language: TransitLanguage) -> String {
        switch language {
        case .english: englishHighlights
        case .traditionalChinese: traditionalHighlights
        case .simplifiedChinese: simplifiedHighlights
        }
    }

    static let all: [Self] = {
        let citybus = URL(string: "https://www.hkcitysightseeing.com/route-info")!
        let hk1 = URL(string: "https://www.kmb.hk/minisite/hk1/en/")!
        let hk2 = URL(string: "https://www.kmb.hk/storage/files/HK2%20Guide_compressed.pdf")!
        return [
            .init(number: "H1", routeOperator: .citybus, englishName: "Heritage Route", traditionalName: "文化古蹟線", simplifiedName: "文化古迹线", englishHighlights: "Central · Wan Chai · Causeway Bay · Tsim Sha Tsui", traditionalHighlights: "中環 · 灣仔 · 銅鑼灣 · 尖沙咀", simplifiedHighlights: "中环 · 湾仔 · 铜锣湾 · 尖沙咀", officialURL: citybus),
            .init(number: "H1S", routeOperator: .citybus, englishName: "HK Art Discovery", traditionalName: "香港藝術之旅", simplifiedName: "香港艺术之旅", englishHighlights: "West Kowloon Cultural District · Wan Chai · Central", traditionalHighlights: "西九文化區 · 灣仔 · 中環", simplifiedHighlights: "西九文化区 · 湾仔 · 中环", officialURL: citybus),
            .init(number: "H2", routeOperator: .citybus, englishName: "Cultural Route", traditionalName: "文化之旅", simplifiedName: "文化之旅", englishHighlights: "Mong Kok · Yau Ma Tei · West Kowloon · Wan Chai", traditionalHighlights: "旺角 · 油麻地 · 西九文化區 · 灣仔", simplifiedHighlights: "旺角 · 油麻地 · 西九文化区 · 湾仔", officialURL: citybus),
            .init(number: "H2K", routeOperator: .citybus, englishName: "Night Scene Hong Kong", traditionalName: "香港夜景之旅", simplifiedName: "香港夜景之旅", englishHighlights: "Temple Street · Tsim Sha Tsui · Central · Peak Tram", traditionalHighlights: "廟街 · 尖沙咀 · 中環 · 山頂纜車", simplifiedHighlights: "庙街 · 尖沙咀 · 中环 · 山顶缆车", officialURL: citybus),
            .init(number: "H3", routeOperator: .citybus, englishName: "Coastliner", traditionalName: "海岸線", simplifiedName: "海岸线", englishHighlights: "Ocean Park · Repulse Bay · Stanley", traditionalHighlights: "海洋公園 · 淺水灣 · 赤柱", simplifiedHighlights: "海洋公园 · 浅水湾 · 赤柱", officialURL: citybus),
            .init(number: "H4", routeOperator: .citybus, englishName: "Coastliner", traditionalName: "海岸線", simplifiedName: "海岸线", englishHighlights: "Stanley · Repulse Bay · Aberdeen · Kennedy Town · Central", traditionalHighlights: "赤柱 · 淺水灣 · 香港仔 · 堅尼地城 · 中環", simplifiedHighlights: "赤柱 · 浅水湾 · 香港仔 · 坚尼地城 · 中环", officialURL: citybus),
            .init(number: "HK1", routeOperator: .kmb, englishName: "CITY CHARM", traditionalName: "城市漫遊", simplifiedName: "城市漫游", englishHighlights: "West Kowloon · Temple Street · Mong Kok · Wong Tai Sin · Kowloon City", traditionalHighlights: "西九龍 · 廟街 · 旺角 · 黃大仙 · 九龍城", simplifiedHighlights: "西九龙 · 庙街 · 旺角 · 黄大仙 · 九龙城", officialURL: hk1),
            .init(number: "HK2", routeOperator: .kmb, englishName: "SKYWALK", traditionalName: "天際漫遊", simplifiedName: "天际漫游", englishHighlights: "Stonecutters Bridge · Tsing Ma Bridge · West Kowloon", traditionalHighlights: "昂船洲大橋 · 青馬大橋 · 西九龍", simplifiedHighlights: "昂船洲大桥 · 青马大桥 · 西九龙", officialURL: hk2)
        ]
    }()
}

struct SightseeingRoutesView: View {
    @Environment(\.transitLanguage) private var language
    private let accent = Color.pink

    var body: some View {
        List {
            Section {
                Text("These are dedicated sightseeing products, not ordinary point-to-point bus recommendations. Check the operator for current fares, departure times, ticket conditions and service changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(SightseeingRoute.Operator.allCases) { routeOperator in
                Section(routeOperator.name(for: language)) {
                    ForEach(SightseeingRoute.all.filter { $0.routeOperator == routeOperator }) { route in
                        routeCard(route)
                    }
                }
            }

            Section("Regular Public Transport") {
                Text("These are ordinary public transport routes that pass useful sightseeing areas. They are not tours, and no attraction visit or view is guaranteed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(RegularSightseeingConnection.all) { connection in
                    NavigationLink {
                        RegularSightseeingRouteListView(connection: connection)
                    } label: {
                        regularConnectionCard(connection)
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    TramView()
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(language == .english ? "Hong Kong Tramways" : "香港電車")
                            .font(.headline)
                        CustomBadgeView(
                            text: language.localized("Regular Public Transport"),
                            backgroundColor: Color.green,
                            isCompact: true
                        )
                        Label(
                            language == .english
                                ? "Northern Hong Kong Island corridor"
                                : language == .traditionalChinese
                                    ? "港島北岸走廊"
                                    : "港岛北岸走廊",
                            systemImage: "tram.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }

            Section {
                Text("Route identities and broad coverage were checked against current operator and Hong Kong Tourism Board information. External websites are independent; HK Way does not sell tickets or guarantee open-top vehicle operation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(accent.opacity(0.09).ignoresSafeArea())
        .navigationTitle("Sightseeing Routes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func regularConnectionCard(_ connection: RegularSightseeingConnection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(connection.title(for: language)).font(.headline)
            CustomBadgeView(
                text: language.localized("Regular Public Transport"),
                backgroundColor: .gray,
                isCompact: true
            )
            Label(connection.coverage(for: language), systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }

    private func routeCard(_ route: SightseeingRoute) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(route.number)
                    .font(.title3.bold())
                    .foregroundStyle(accent)
                Text(route.name(for: language))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            CustomBadgeView(
                text: language.localized("Dedicated Sightseeing Service"),
                backgroundColor: accent,
                isCompact: true
            )

            Label(route.highlights(for: language), systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Link(destination: route.officialURL) {
                Label("Official Route, Fare and Ticket Information", systemImage: "arrow.up.right.square")
                    .font(.footnote)
            }
        }
        .padding(.vertical, 5)
    }
}

private struct RegularSightseeingRouteListView: View {
    let connection: RegularSightseeingConnection
    @Environment(\.transitLanguage) private var language
    @Query(sort: \RouteEntity.number) private var routes: [RouteEntity]

    private var matches: [RouteEntity] {
        routes.filter { route in
            connection.numbers.contains(route.number.uppercased()) &&
                route.operators.contains { $0.id == connection.operatorID }
        }
        .sorted {
            let numberOrder = $0.number.localizedStandardCompare($1.number)
            if numberOrder != .orderedSame { return numberOrder == .orderedAscending }
            return $0.displayDestination(for: language)
                .localizedStandardCompare($1.displayDestination(for: language)) == .orderedAscending
        }
    }

    var body: some View {
        List {
            Section {
                Text("Regular service — check the selected direction, operating days and current service information before travelling.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Matching Routes") {
                if matches.isEmpty {
                    ContentUnavailableView(
                        "No Matching Routes",
                        systemImage: "bus.fill",
                        description: Text("Update the dataset and try again.")
                    )
                } else {
                    ForEach(matches) { route in
                        NavigationLink {
                            RouteDetailView(route: route)
                        } label: {
                            RouteRowView(
                                route: route,
                                etaResult: nil,
                                isCompact: true,
                                allowsTwoLineOrigin: true,
                                allowsTwoLineDestination: true,
                                allowsFullNameWrapping: true,
                                usesUniformNameStyle: true
                            )
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle(connection.title(for: language))
        .navigationBarTitleDisplayMode(.inline)
    }
}
