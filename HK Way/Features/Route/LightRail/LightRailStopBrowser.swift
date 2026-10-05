import SwiftUI

struct LightRailStopBrowser: View {
    var onSelect: ((LightRailStopCatalogueEntry) -> Void)?

    init(onSelect: ((LightRailStopCatalogueEntry) -> Void)? = nil) {
        self.onSelect = onSelect
    }

    @Environment(\.transitLanguage) private var language
    @State private var area: LightRailArea = .all
    @State private var query = ""
    @State private var entries: [LightRailStopCatalogueEntry] = []
    @State private var loaded = false
    @State private var failed = false
    @AppStorage(LightRailStopFavorite.storageKey)
    private var favoriteStopIDsValue = ""

    private var filtered: [LightRailStopCatalogueEntry] {
        entries.filter { (area == .all || $0.area == area) && $0.matches(query) }
    }

    private var favorites: [LightRailStopCatalogueEntry] {
        let ids = LightRailStopFavorite.ids(from: favoriteStopIDsValue)
        return entries.filter { ids.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 12) {
            if !favorites.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(favoriteSectionTitle)
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(favorites) { entry in
                                if let onSelect {
                                    Button {
                                        onSelect(entry)
                                    } label: {
                                        Label(name(entry.stop), systemImage: "bookmark.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .frame(minHeight: 44)
                                            .background(
                                                Color.orange.opacity(0.14),
                                                in: Capsule()
                                            )
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink {
                                        LightRailStopETAView(
                                            stop: entry.stop,
                                            servedRouteIDs: entry.routeIDs
                                        )
                                    } label: {
                                    Label(name(entry.stop), systemImage: "bookmark.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .frame(minHeight: 44)
                                        .background(
                                            Color.orange.opacity(0.14),
                                            in: Capsule()
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search Light Rail Stops", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear Search")
                }
            }
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LightRailArea.allCases) { option in
                        Button { area = option } label: {
                            HStack(spacing: 5) {
                                if area == option { Image(systemName: "checkmark") }
                                Text(LocalizedStringKey(option.rawValue))
                            }
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(area == option ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04), in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(area == option ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }

            if failed {
                ContentUnavailableView("Unable to Load Light Rail Stops", systemImage: "tram.fill")
            } else if !loaded {
                ProgressView("Loading Light Rail Stops…")
                Spacer()
            } else if filtered.isEmpty {
                ContentUnavailableView("No Matching Light Rail Stops", systemImage: "magnifyingglass")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { entry in
                            Group {
                                if let onSelect {
                                    Button {
                                        onSelect(entry)
                                    } label: {
                                        stopRow(entry)
                                    }
                                } else {
                                    NavigationLink {
                                        LightRailStopETAView(stop: entry.stop, servedRouteIDs: entry.routeIDs)
                                    } label: {
                                        stopRow(entry)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
        .foregroundStyle(.primary)
        .task {
            guard !loaded else { return }
            do { entries = try LightRailStopCatalogue.load() }
            catch { failed = true }
            loaded = true
        }
    }

    private func stopRow(_ entry: LightRailStopCatalogueEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(name(entry.stop)).font(.headline)
                if language != .english,
                   !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(entry.stop.english).font(.caption).foregroundStyle(.secondary)
                }
                Text(entry.routeIDs.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .customInfoCardSurface(cornerRadius: 22)
    }

    private func name(_ stop: LightRailStop) -> String {
        switch language {
        case .english: stop.english
        case .traditionalChinese: stop.traditional
        case .simplifiedChinese: stop.simplified
        }
    }

    private var favoriteSectionTitle: String {
        switch language {
        case .english: "Favorite Light Rail Stops"
        case .traditionalChinese: "已收藏輕鐵車站"
        case .simplifiedChinese: "已收藏轻铁车站"
        }
    }
}

struct LightRailRouteBadge: View {
    let number: String
    private var route: LightRailRoute? { LightRailRoute.regularRoutes.first { $0.id == number } }
    var body: some View {
        Text(number)
            .font(.subheadline.bold())
            .foregroundStyle(route.map { $0.usesDarkText ? Color.black : Color.white } ?? Color.primary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(route?.color ?? Color.secondary.opacity(0.15), in: Capsule())
            .fixedSize()
    }
}

struct LightRailFavoritesView: View {
    @Environment(\.transitLanguage) private var language
    @AppStorage(LightRailStopFavorite.storageKey) private var stored = ""
    @State private var entries: [LightRailStopCatalogueEntry] = []
    @State private var loaded = false
    @State private var failed = false

    private var favorites: [LightRailStopCatalogueEntry] {
        let ids = LightRailStopFavorite.ids(from: stored)
        return entries.filter { ids.contains($0.id) }
    }

    var body: some View {
        Group {
            if LightRailStopFavorite.ids(from: stored).isEmpty {
                CustomCardView(
                    imageIcon: "tram.fill",
                    title: emptyTitle,
                    subTitle: emptyDescription,
                    animated: false
                )
            } else if failed {
                ContentUnavailableView(
                    "Unable to Load Light Rail Stops",
                    systemImage: "tram.fill"
                )
            } else if !loaded {
                ProgressView("Loading Light Rail Stops…")
            } else {
                List(favorites) { entry in
                    NavigationLink {
                        LightRailStopETAView(
                            stop: entry.stop,
                            servedRouteIDs: entry.routeIDs
                        )
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "tram.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(name(entry.stop)).font(.headline)
                                Text(entry.routeIDs.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            stored = LightRailStopFavorite.toggling(
                                entry.id,
                                in: stored
                            )
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .foregroundStyle(.primary)
        .task {
            guard !loaded else { return }
            do {
                entries = try LightRailStopCatalogue.load()
            } catch {
                failed = true
            }
            loaded = true
        }
    }

    private func name(_ stop: LightRailStop) -> String {
        switch language {
        case .english: stop.english
        case .traditionalChinese: stop.traditional
        case .simplifiedChinese: stop.simplified
        }
    }

    private var emptyTitle: String {
        switch language {
        case .english: "No Favorite Light Rail Stops"
        case .traditionalChinese: "沒有收藏的輕鐵車站"
        case .simplifiedChinese: "没有收藏的轻铁车站"
        }
    }

    private var emptyDescription: String {
        switch language {
        case .english: "Light Rail stops you save will appear here."
        case .traditionalChinese: "你收藏的輕鐵車站會顯示在此處。"
        case .simplifiedChinese: "你收藏的轻铁车站会显示在此处。"
        }
    }
}
