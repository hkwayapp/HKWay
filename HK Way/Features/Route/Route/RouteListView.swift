//
//  RouteListView.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import SwiftUI
import SwiftData

struct RouteListView: View {

    @Environment(\.transitLanguage)
    private var transitLanguage

    let isSearchTabSelected: Bool
    let keyboardActivationID: Int
    let onMenuTap: () -> Void

    init(
        isSearchTabSelected: Bool = true,
        keyboardActivationID: Int = 0,
        onMenuTap: @escaping () -> Void = {}
    ) {
        self.isSearchTabSelected = isSearchTabSelected
        self.keyboardActivationID = keyboardActivationID
        self.onMenuTap = onMenuTap
    }

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    @State
    private var searchText = ""

    @State
    private var isCustomKeyboardVisible =
        false

    @State
    private var enabledKeyboardKeys:
        Set<String> = []

    @State
    private var searchRecords: [RouteSearchRecord] = []

    @State
    private var selectedRouteID: String?

    @State
    private var routePrefixIndex:
        [String: [RouteSearchRecord]] = [:]

    @AppStorage(OperatorSelectionPreference.storageKey)
    private var selectedOperatorIdsValue = ""

    @State
    private var operatorFilter: NearbyOperatorFilter = .preferences

    private var settingsOperatorIds: Set<String> {
        OperatorSelectionPreference.ids(
            from: selectedOperatorIdsValue
        )
    }

    private var filteredRoutes: [RouteEntity] {
        let query = searchText.uppercased()
        let records = routePrefixIndex[query] ?? []

        return records
            .compactMap { record in
                if !operatorFilter.includes(
                    record.operatorIds,
                    preferences: settingsOperatorIds
                ) {
                    return nil
                }

                return record.route
            }
    }

    private var filteredResidentRoutes: [MaWanResidentBusRoute] {
        guard operatorFilter.includes(
            ["PI"],
            preferences: settingsOperatorIds
        ) else { return [] }
        let query = searchText.uppercased()
        return MaWanResidentBusCatalogue.routes.filter {
            query.isEmpty || $0.number.hasPrefix(query)
        }
    }

    private var allOperatorIds:
        [String] {

        Array(
            Set(
                searchRecords.flatMap {
                    $0.operatorIds
                }
            ).union(["PI"])
        )
        .sorted()
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                NavigationSplitView {
                    searchScreen
                        .navigationSplitViewColumnWidth(
                            min: 360,
                            ideal: 420,
                            max: 480
                        )
                } detail: {
                    searchDetail
                }
            } else {
                searchScreen
            }
        }
    }

    private var searchScreen: some View {
        let displayedRoutes = filteredRoutes
        let displayedResidentRoutes = filteredResidentRoutes

        return NavigationStack {
            ZStack {
                CustomAppBackgroundView()

                VStack(spacing: 0) {
                    if displayedRoutes.isEmpty && displayedResidentRoutes.isEmpty {

                        CustomCardView(
                            imageIcon: "magnifyingglass",
                            title: "No Routes Found",
                            subTitle: "Try another route number or operator.",
                            animated: true
                        )

                    } else {

                        List {
                            ForEach(displayedRoutes) { route in
                                Group {
                                    if UIDevice.current.userInterfaceIdiom == .pad {
                                        Button {
                                            selectedRouteID = route.id
                                        } label: {
                                            searchRouteRow(route)
                                        }
                                    } else {
                                        NavigationLink {
                                            RouteDetailView(route: route)
                                        } label: {
                                            searchRouteRow(route)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            if !displayedResidentRoutes.isEmpty {
                                Section("Resident Bus") {
                                    ForEach(displayedResidentRoutes) { route in
                                        Link(destination: route.officialURL) {
                                            ResidentBusSearchRow(route: route)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .onScrollPhaseChange {
                            _, newPhase in

                            guard
                                newPhase.isScrolling,
                                isCustomKeyboardVisible
                            else {
                                return
                            }

                            withAnimation {
                                isCustomKeyboardVisible =
                                    false
                            }
                        }
                    }
                }
            }

            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onMenuTap) {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("Menu")
                }

                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    operatorFilterMenu
                }

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Button {
                        withAnimation {
                            isCustomKeyboardVisible
                                .toggle()
                        }
                    } label: {
                        Image(
                            systemName:
                                isCustomKeyboardVisible
                                ? "keyboard.chevron.compact.down"
                                : "keyboard"
                        )
                    }
                    .accessibilityLabel(
                        isCustomKeyboardVisible
                        ? "Hide route keyboard"
                        : "Show route keyboard"
                    )
                }
            }
            .safeAreaInset(
                edge: .bottom,
                spacing: 0
            ) {

                VStack(spacing: 0) {
                    if isCustomKeyboardVisible {

                        CustomRouteKeyboardView(
                            text: $searchText,
                            enabledKeys:
                                enabledKeyboardKeys
                        )
                        .padding(
                            .bottom,
                            UIDevice.current.userInterfaceIdiom == .phone
                                ? 68
                                : 0
                        )
                        .background(Color(.systemGray5))
                        .transition(
                            .move(edge: .bottom)
                                .combined(
                                    with: .opacity
                                )
                        )
                    }
                }
            }
            .onChange(of: isSearchTabSelected) {
                _, isSelected in

                guard isSelected else {
                    return
                }

                searchText = ""

                withAnimation {
                    isCustomKeyboardVisible = true
                }

                refreshEnabledKeyboardKeys()
            }
            .onChange(of: isCustomKeyboardVisible) {
                _, _ in
                refreshEnabledKeyboardKeys()
            }
            .onChange(of: searchText) {
                _, _ in
                refreshEnabledKeyboardKeys()
            }
            .onChange(of: selectedOperatorIdsValue) {
                _, _ in
                refreshEnabledKeyboardKeys()
            }
            .onChange(of: routes.count) {
                _, _ in
                refreshSearchIndex()
            }
            .task {
                refreshSearchIndex()
            }
            .task(id: keyboardActivationID) {
                guard keyboardActivationID > 0 else { return }

                searchText = ""
                withAnimation {
                    isCustomKeyboardVisible = true
                }
                refreshEnabledKeyboardKeys()
            }
        }
    }

    @ViewBuilder
    private var searchDetail: some View {
        ZStack {
            CustomAppBackgroundView()

            if let route = routes.first(where: { $0.id == selectedRouteID }) {
                NavigationStack {
                    RouteDetailView(route: route)
                }
            } else {
                ContentUnavailableView(
                    searchSelectionTitle,
                    systemImage: "magnifyingglass",
                    description: Text(searchSelectionDescription)
                )
            }
        }
    }

    private func searchRouteRow(_ route: RouteEntity) -> some View {
        RouteRowView(
            route: route,
            etaResult: nil,
            isCompact: true,
            allowsTwoLineOrigin: true,
            allowsTwoLineDestination: true,
            usesUniformNameStyle: true
        )
    }

    private var searchSelectionTitle: String {
        switch transitLanguage {
        case .english: "Select a Route"
        case .traditionalChinese: "選擇路線"
        case .simplifiedChinese: "选择路线"
        }
    }

    private var searchSelectionDescription: String {
        switch transitLanguage {
        case .english: "Choose a route from the search results."
        case .traditionalChinese: "從搜尋結果選擇路線。"
        case .simplifiedChinese: "从搜索结果选择路线。"
        }
    }

    // MARK: - Keyboard

    private func refreshEnabledKeyboardKeys() {

        guard
            isSearchTabSelected,
            isCustomKeyboardVisible
        else {
            enabledKeyboardKeys = []
            return
        }

        let validKeys = Set(
            Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                .map(String.init)
        )

        let query = searchText.uppercased()

        var nextKeys: Set<String> = []

        for record in routePrefixIndex[query] ?? [] {
            let routeNumber = record.routeNumber

            guard query.count < routeNumber.count else {
                continue
            }

            let keyIndex = routeNumber.index(
                routeNumber.startIndex,
                offsetBy: query.count
            )
            let key = String(routeNumber[keyIndex])

            if validKeys.contains(key) {
                nextKeys.insert(key)
            }
        }

        if operatorFilter.includes(
            ["PI"],
            preferences: settingsOperatorIds
        ) {
            for route in MaWanResidentBusCatalogue.routes where route.number.hasPrefix(query) {
                guard query.count < route.number.count else { continue }
                let index = route.number.index(route.number.startIndex, offsetBy: query.count)
                nextKeys.insert(String(route.number[index]))
            }
        }

        enabledKeyboardKeys = nextKeys
    }

    @MainActor
    private func refreshSearchIndex() {
        let records = routes.map { route in
            RouteSearchRecord(
                route: route,
                routeNumber: route.number.uppercased(),
                operatorIds: operatorIds(for: route)
            )
        }

        var prefixIndex: [String: [RouteSearchRecord]] = [
            "": records
        ]

        for record in records {
            var prefix = ""

            for character in record.routeNumber {
                prefix.append(character)
                prefixIndex[prefix, default: []]
                    .append(record)
            }
        }

        searchRecords = records
        routePrefixIndex = prefixIndex
        refreshEnabledKeyboardKeys()
    }

    // MARK: - Operator Filter

    private var operatorFilterMenu:
        some View {

        Menu {

            Button {
                operatorFilter = .all
                refreshEnabledKeyboardKeys()
            } label: {

                if operatorFilter == .all {
                    Label(
                        "All Operators",
                        systemImage: "checkmark"
                    )
                } else {
                    Text("All Operators")
                }
            }

            Divider()

            Button {
                operatorFilter = .preferences
                refreshEnabledKeyboardKeys()
            } label: {
                if operatorFilter == .preferences {
                    Label(
                        "Use Settings Preferences",
                        systemImage: "checkmark"
                    )
                } else {
                    Text("Use Settings Preferences")
                }
            }

            Divider()

            ForEach(
                allOperatorIds,
                id: \.self
            ) { operatorId in

                Button {
                    toggleOperator(operatorId)
                } label: {

                    if operatorFilter.isSelected(operatorId) {

                        Label(
                            CustomBadgeView.displayText(
                                for: operatorId,
                                language: transitLanguage
                            ),
                            systemImage: "checkmark"
                        )

                    } else {
                        Text(
                            CustomBadgeView.displayText(
                                for: operatorId,
                                language: transitLanguage
                            )
                        )
                    }
                }
            }

        } label: {

            Image(
                systemName:
                    operatorFilter == .all
                        || (operatorFilter == .preferences
                            && settingsOperatorIds.isEmpty)
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .accessibilityLabel(
            "Filter by operator"
        )
    }

    private func operatorIds(
        for route: RouteEntity
    ) -> Set<String> {

        Set(
            route.operators.flatMap {
                $0.id.split(separator: "+")
                    .map(String.init)
            }
        )
    }

    private func toggleOperator(_ operatorId: String) {
        operatorFilter.toggle(operatorId)
        refreshEnabledKeyboardKeys()
    }

}

private struct ResidentBusSearchRow: View {
    let route: MaWanResidentBusRoute

    var body: some View {
        HStack(spacing: 12) {
            Text(route.number)
                .font(.title3.bold())
                .frame(minWidth: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                CustomBadgeView(operatorId: "PI", isCompact: true)
                Text("Ma Wan").font(.caption).foregroundStyle(.secondary)
                Text(LocalizedStringKey(route.destination))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Official route document")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "arrow.up.right.square")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
    }
}

private struct RouteSearchRecord: Identifiable {
    let route: RouteEntity
    let routeNumber: String
    let operatorIds: Set<String>

    var id: String { route.id }
}



#Preview {
    RouteListView()
        .modelContainer(
            for: [
                OperatorEntity.self,
                RouteEntity.self
            ],
            inMemory: true
        )
}
