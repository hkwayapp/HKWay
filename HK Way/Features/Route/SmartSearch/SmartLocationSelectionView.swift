import SwiftUI
import SwiftData

struct SmartSearchLocation: Identifiable, Hashable {
    let id: String
    let nameEnglish: String
    let nameTraditional: String
    let nameSimplified: String

    init(stop: StopEntity) {
        id = Self.normalized(stop.displayNameEnglish)
        nameEnglish = stop.displayNameEnglish
        nameTraditional = stop.displayNameTraditional
        nameSimplified = stop.displayNameSimplified
    }

    func title(for language: TransitLanguage) -> String {
        switch language {
        case .english: nameEnglish
        case .traditionalChinese:
            Self.bilingualName(
                chinese: nameTraditional,
                english: nameEnglish
            )
        case .simplifiedChinese:
            Self.bilingualName(
                chinese: nameSimplified,
                english: nameEnglish
            )
        }
    }

    func matches(stop: StopEntity?) -> Bool {
        guard let stop else {
            return false
        }

        return Self.normalized(stop.displayNameEnglish) == id
    }

    private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_HK")
        )
    }

    private static func bilingualName(
        chinese: String,
        english: String
    ) -> String {
        guard !english.isEmpty,
              chinese.localizedCaseInsensitiveCompare(english)
                != .orderedSame
        else {
            return chinese
        }

        return "\(chinese)  \(english)"
    }
}

struct SmartLocationSelectionView: View {
    let districtId: String
    let community: SmartSearchCommunity?
    @Binding var selection: SmartSearchLocation?

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Environment(\.dismiss)
    private var dismiss

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    @State private var searchText = ""
    @State private var locations: [SmartSearchLocation] = []
    @State private var isLoading = true

    private var filteredLocations: [SmartSearchLocation] {
        guard !searchText.isEmpty else {
            return locations
        }

        return locations.filter {
            $0.title(for: transitLanguage)
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading Locations...")
                        .foregroundStyle(.secondary)
                }
            } else if filteredLocations.isEmpty {
                ContentUnavailableView(
                    "No Locations Found",
                    systemImage: "mappin.slash",
                    description: Text(
                        "Try another search or district."
                    )
                )
            } else {
                List {
                    if selection != nil {
                        Section {
                            Button {
                                selection = nil
                                dismiss()
                            } label: {
                                Label(
                                    community == nil
                                        ? "Use Whole District"
                                        : "Use Whole Community",
                                    systemImage: "xmark.circle"
                                )
                                .foregroundStyle(.primary)
                            }
                        }
                    }

                    Section("Stops") {
                        ForEach(filteredLocations) { location in
                            Button {
                                selection = location
                                dismiss()
                            } label: {
                                selectionLabel(
                                    title: location.title(
                                        for: transitLanguage
                                    ),
                                    isSelected: selection == location
                                )
                            }
                            .tint(.primary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Select Location")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            prompt: "Search Locations"
        )
        .task(id: "\(districtId)|\(community?.id ?? "all")|\(routes.count)") {
            await loadLocations(
                for: districtId,
                community: community
            )
        }
    }

    @MainActor
    private func loadLocations(
        for requestedDistrictId: String,
        community requestedCommunity: SmartSearchCommunity?
    ) async {
        isLoading = true
        locations = []
        searchText = ""

        await Task.yield()

        var locationsById: [String: SmartSearchLocation] = [:]

        for route in routes {
            guard !Task.isCancelled else {
                return
            }

            for journey in route.journeys {
                for journeyStop in journey.journeyStops {
                    guard let stop = journeyStop.stop,
                          stop.districtId == requestedDistrictId,
                          requestedCommunity?.matches(stop: stop) ?? true
                    else {
                        continue
                    }

                    let location = SmartSearchLocation(stop: stop)
                    locationsById[location.id] =
                        locationsById[location.id] ?? location
                }
            }
        }

        guard !Task.isCancelled,
              requestedDistrictId == districtId
        else {
            return
        }

        locations = locationsById.values.sorted {
            $0.title(for: transitLanguage).localizedStandardCompare(
                $1.title(for: transitLanguage)
            ) == .orderedAscending
        }
        isLoading = false
    }

    private func selectionLabel(
        title: String,
        isSelected: Bool
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(.rect)
    }
}
