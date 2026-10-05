import SwiftUI
import SwiftData

struct SmartRouteResultsView: View {
    let originDistrictId: String
    let destinationDistrictId: String
    let originCommunity: SmartSearchCommunity?
    let destinationCommunity: SmartSearchCommunity?
    let originLocation: SmartSearchLocation?
    let destinationLocation: SmartSearchLocation?

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    @State private var matchingResults: [SmartRouteMatch]?

    private func findMatchingResults() -> [SmartRouteMatch] {
        routes
            .compactMap { route in
                route.journeys.compactMap { journey in
                    journey.bestMatch(
                        route: route,
                        from: originDistrictId,
                        originCommunity: originCommunity,
                        originLocation: originLocation,
                        to: destinationDistrictId,
                        destinationCommunity: destinationCommunity,
                        destinationLocation: destinationLocation
                    )
                }
                .min { SmartRouteMatch.isMoreUseful($0, $1) }
            }
            .sorted { lhs, rhs in
                if lhs.stopsTravelled != rhs.stopsTravelled {
                    return lhs.stopsTravelled < rhs.stopsTravelled
                }

                let lhsDuration = lhs.journey.scheduledDurationMinutes
                    ?? Int.max
                let rhsDuration = rhs.journey.scheduledDurationMinutes
                    ?? Int.max

                if lhsDuration != rhsDuration {
                    return lhsDuration < rhsDuration
                }

                let numberComparison = lhs.route.number
                    .localizedStandardCompare(rhs.route.number)

                if numberComparison != .orderedSame {
                    return numberComparison == .orderedAscending
                }

                return lhs.route.displayDestination(for: transitLanguage)
                    .localizedStandardCompare(
                        rhs.route.displayDestination(for: transitLanguage)
                    ) == .orderedAscending
            }
    }

    var body: some View {
        Group {
            if let matchingResults {
                if matchingResults.isEmpty {
                ContentUnavailableView(
                    noRoutesTitle,
                    systemImage: "bus",
                    description: Text(noRoutesDescription)
                )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(matchingResults) { result in
                                NavigationLink {
                                    RouteDetailView(route: result.route)
                                } label: {
                                    VStack(alignment: .leading, spacing: 14) {
                                        RouteRowView(
                                            route: result.route,
                                            etaResult: nil,
                                            isCompact: true,
                                            allowsTwoLineOrigin: true,
                                            allowsTwoLineDestination: true,
                                            usesUniformNameStyle: true
                                        )

                                        Divider()

                                        journeyPointRow(
                                            label: "Board at",
                                            systemImage: "arrow.up.circle.fill",
                                            color: .accentColor,
                                            stop: result.boardingStop.stop
                                        )

                                        journeyPointRow(
                                            label: "Alight at",
                                            systemImage: "arrow.down.circle.fill",
                                            color: .orange,
                                            stop: result.alightingStop.stop
                                        )
                                    }
                                    .padding(16)
                                    .background(
                                        Color(uiColor: .systemBackground),
                                        in: .rect(cornerRadius: 22)
                                    )
                                    .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(resultsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await Task.yield()
            matchingResults = findMatchingResults()
        }
    }

    private func journeyPointRow(
        label: LocalizedStringKey,
        systemImage: String,
        color: Color,
        stop: StopEntity?
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .font(.body.weight(.semibold))

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(
                    verbatim: stop?.smartSearchDisplayName(
                        for: transitLanguage
                    ) ?? ""
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultsTitle: String {
        transitLanguage.localized("Suggested Routes")
    }

    private var noRoutesTitle: String {
        transitLanguage.localized("No Direct Routes Found")
    }

    private var noRoutesDescription: String {
        transitLanguage.localized(
            "Try another origin or destination district."
        )
    }
}

private extension StopEntity {
    func smartSearchDisplayName(
        for language: TransitLanguage
    ) -> String {
        let localizedName = displayName(for: language)

        guard language != .english,
              !displayNameEnglish.isEmpty,
              localizedName.localizedCaseInsensitiveCompare(
                displayNameEnglish
              ) != .orderedSame
        else {
            return localizedName
        }

        return "\(localizedName)  \(displayNameEnglish)"
    }
}

private struct SmartRouteMatch: Identifiable {
    let route: RouteEntity
    let journey: JourneyEntity
    let boardingStop: JourneyStopEntity
    let alightingStop: JourneyStopEntity
    let stopsTravelled: Int

    var id: String { route.id }

    static func isMoreUseful(
        _ lhs: SmartRouteMatch,
        _ rhs: SmartRouteMatch
    ) -> Bool {
        if lhs.stopsTravelled != rhs.stopsTravelled {
            return lhs.stopsTravelled < rhs.stopsTravelled
        }

        return (lhs.journey.scheduledDurationMinutes ?? Int.max)
            < (rhs.journey.scheduledDurationMinutes ?? Int.max)
    }
}

private extension JourneyEntity {
    func bestMatch(
        route: RouteEntity,
        from originDistrictId: String,
        originCommunity: SmartSearchCommunity?,
        originLocation: SmartSearchLocation?,
        to destinationDistrictId: String,
        destinationCommunity: SmartSearchCommunity?,
        destinationLocation: SmartSearchLocation?
    ) -> SmartRouteMatch? {
        let orderedStops = journeyStops.sorted(by: {
            $0.sequence < $1.sequence
        })
        var bestMatch: SmartRouteMatch?

        for originIndex in orderedStops.indices {
            let boardingStop = orderedStops[originIndex]

            guard boardingStop.stop?.districtId == originDistrictId,
                  originCommunity?.matches(stop: boardingStop.stop) ?? true,
                  originLocation?.matches(stop: boardingStop.stop) ?? true,
                  boardingStop.stopPickDrop != "1"
            else {
                continue
            }

            for destinationIndex in orderedStops.indices
                where destinationIndex > originIndex {
                let alightingStop = orderedStops[destinationIndex]

                guard alightingStop.stop?.districtId == destinationDistrictId,
                      destinationCommunity?.matches(
                        stop: alightingStop.stop
                      ) ?? true,
                      destinationLocation?.matches(stop: alightingStop.stop)
                        ?? true,
                      alightingStop.stopPickDrop != "2"
                else {
                    continue
                }

                let candidate = SmartRouteMatch(
                    route: route,
                    journey: self,
                    boardingStop: boardingStop,
                    alightingStop: alightingStop,
                    stopsTravelled: destinationIndex - originIndex
                )

                if let currentBestMatch = bestMatch {
                    if SmartRouteMatch.isMoreUseful(
                        candidate,
                        currentBestMatch
                    ) {
                        bestMatch = candidate
                    }
                } else {
                    bestMatch = candidate
                }

                break
            }
        }

        return bestMatch
    }
}
