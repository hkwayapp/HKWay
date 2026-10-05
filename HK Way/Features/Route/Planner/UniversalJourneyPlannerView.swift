import SwiftData
import SwiftUI
import CoreLocation

@MainActor
struct UniversalJourneyPlannerView: View {
    @Environment(\.transitLanguage) private var language
    @Environment(AppLocationManager.self) private var locationManager
    @Query private var stops: [StopEntity]
    @Query private var journeys: [JourneyEntity]

    @State private var origin: UniversalPlannerEndpoint?
    @State private var destination: UniversalPlannerEndpoint?
    @State private var selectingOrigin = true
    @State private var isSelecting = false
    @State private var searched = false
    @State private var isPlanning = false
    @State private var plannedJourneys: [UniversalPlannedJourney] = []
    @State private var mtrJourneys: [UniversalMTRJourney] = []
    @State private var islandJourneys: [UniversalIslandJourney] = []
    @State private var sortOption = PlannerSortOption.fastest
    @State private var servicePeriod = PlannerServicePeriod.normal
    @State private var mtrStations: [MTRStation] = []
    @State private var hasAutomaticallySelectedOrigin = false

    private var endpoints: [UniversalPlannerEndpoint] {
        stops.map(UniversalPlannerEndpoint.stop)
            + mtrStations.map(UniversalPlannerEndpoint.station)
            + FerryPier.allCases.map(UniversalPlannerEndpoint.pier)
    }

    private var sightseeingEndpoints: [UniversalPlannerEndpoint] {
        let parks = ThemeParkDestination.allCases.compactMap { destination in
            sightseeingPlace(
                id: destination.rawValue,
                english: destination.title(for: .english),
                traditional: destination.title(for: .traditionalChinese),
                simplified: destination.title(for: .simplifiedChinese),
                mtrStationID: destination.stationID,
                matches: destination.matches
            )
        }
        let otherPlaces = [
            sightseeingPlace(
                id: "tian-tan-buddha",
                english: "Tian Tan Buddha",
                traditional: "天壇大佛",
                simplified: "天坛大佛",
                matches: { $0.id == "11013" }
            ),
            sightseeingPlace(
                id: "ma-wan",
                english: "Ma Wan",
                traditional: "馬灣",
                simplified: "马湾",
                matches: { $0.nameEnglish.localizedCaseInsensitiveContains("Ma Wan") }
            ),
            sightseeingPlace(
                id: "tsz-shan-monastery",
                english: "Tsz Shan Monastery",
                traditional: "慈山寺",
                simplified: "慈山寺",
                matches: { $0.nameEnglish.localizedCaseInsensitiveContains("Tsz Shan") }
            )
        ].compactMap { $0 }
        return parks + otherPlaces
    }

    private func sightseeingPlace(
        id: String,
        english: String,
        traditional: String,
        simplified: String,
        mtrStationID: String? = nil,
        matches: (StopEntity) -> Bool
    ) -> UniversalPlannerEndpoint? {
        let matchingStops = stops.filter(matches)
        guard !matchingStops.isEmpty else { return nil }
        let count = Double(matchingStops.count)
        return .place(
            id: id,
            english: english,
            traditional: traditional,
            simplified: simplified,
            latitude: matchingStops.reduce(0) { $0 + $1.latitude } / count,
            longitude: matchingStops.reduce(0) { $0 + $1.longitude } / count,
            mtrStationID: mtrStationID
        )
    }

    private var airportEndpoints: [UniversalPlannerEndpoint] {
        stops.filter {
            $0.nameEnglish.localizedCaseInsensitiveContains("airport")
        }
        .map(UniversalPlannerEndpoint.stop)
    }

    private var sortedResults: [UniversalPlannedJourney] {
        plannedJourneys.sorted { lhs, rhs in
            if lhs.routePreference != rhs.routePreference {
                return lhs.routePreference < rhs.routePreference
            }
            switch sortOption {
            case .fastest:
                if lhs.totalMinutes != rhs.totalMinutes { return lhs.totalMinutes < rhs.totalMinutes }
            case .leastWalking:
                if lhs.totalWalkDistance != rhs.totalWalkDistance { return lhs.totalWalkDistance < rhs.totalWalkDistance }
            case .lowestFare:
                if lhs.totalFareCents != rhs.totalFareCents {
                    return (lhs.totalFareCents ?? Int.max) < (rhs.totalFareCents ?? Int.max)
                }
            }
            return lhs.transferCount < rhs.transferCount
        }
    }

    private var sortedDisplayResults: [PlannerDisplayResult] {
        let values = plannedJourneys.map(PlannerDisplayResult.bus)
            + mtrJourneys.map(PlannerDisplayResult.mtr)
            + islandJourneys.map(PlannerDisplayResult.island)
        return values.sorted { lhs, rhs in
            switch sortOption {
            case .fastest:
                if lhs.minutes != rhs.minutes { return lhs.minutes < rhs.minutes }
                if lhs.walkingDistance != rhs.walkingDistance {
                    return lhs.walkingDistance < rhs.walkingDistance
                }
            case .leastWalking:
                if lhs.walkingDistance != rhs.walkingDistance {
                    return lhs.walkingDistance < rhs.walkingDistance
                }
                if lhs.minutes != rhs.minutes { return lhs.minutes < rhs.minutes }
            case .lowestFare:
                if lhs.fareCents != rhs.fareCents {
                    return (lhs.fareCents ?? .max) < (rhs.fareCents ?? .max)
                }
                if lhs.minutes != rhs.minutes { return lhs.minutes < rhs.minutes }
            }
            return lhs.id < rhs.id
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(localized(
                    "Choose a supported local stop, station, pier or destination.",
                    "選擇已支援的本地車站、碼頭或目的地。",
                    "选择已支持的本地车站、码头或目的地。"
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    Menu {
                        Picker(selection: $servicePeriod) {
                            ForEach(PlannerServicePeriod.allCases) { period in
                                Text(servicePeriodTitle(period)).tag(period)
                            }
                        } label: { EmptyView() }
                    } label: {
                        Label(servicePeriodTitle(servicePeriod), systemImage: "clock")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                    }
                }

                endpointButton(
                    title: localized("From", "出發地", "出发地"),
                    endpoint: origin,
                    placeholder: originPlaceholder
                ) {
                    selectingOrigin = true
                    isSelecting = true
                }
                endpointButton(
                    title: localized("To", "目的地", "目的地"),
                    endpoint: destination,
                    placeholder: localized("Choose a stop or service", "選擇車站或服務", "选择车站或服务")
                ) {
                    selectingOrigin = false
                    isSelecting = true
                }

                Button {
                    Task { await planJourneys() }
                } label: {
                    if isPlanning {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 48)
                    } else {
                        Label(localized("Find journeys", "尋找行程", "寻找行程"), systemImage: "arrow.triangle.branch")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPlanning || origin == nil || destination == nil || origin == destination)

                if searched {
                    results
                }
            }
            .padding(16)
        }
        .background(Color.gray.opacity(0.08).ignoresSafeArea())
        .navigationTitle(localized("Journey Planner", "行程規劃", "行程规划"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isSelecting) {
            UniversalEndpointPicker(
                endpoints: endpoints,
                sightseeingEndpoints: sightseeingEndpoints,
                airportEndpoints: airportEndpoints,
                isOrigin: selectingOrigin
            ) { endpoint in
                if selectingOrigin { origin = endpoint } else { destination = endpoint }
                searched = false
                plannedJourneys = []
                mtrJourneys = []
                islandJourneys = []
                isSelecting = false
            }
            .environment(\.transitLanguage, language)
        }
        .task {
            if mtrStations.isEmpty {
                mtrStations = (try? MTRStations.loadFareStations(airportExpress: false).map(\.station)) ?? []
            }
        }
        .task {
            locationManager.requestLocation(force: true)
            selectNearestOriginIfNeeded()
        }
        .onChange(of: locationManager.location?.timestamp) { _, _ in
            selectNearestOriginIfNeeded()
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationManager.requestLocation(force: true)
                selectNearestOriginIfNeeded()
            }
        }
        .onChange(of: stops.count) { _, _ in
            selectNearestOriginIfNeeded()
        }
        .onChange(of: servicePeriod) { _, _ in
            searched = false
            plannedJourneys = []
            mtrJourneys = []
            islandJourneys = []
        }
    }

    private func endpointButton(
        title: String,
        endpoint: UniversalPlannerEndpoint?,
        placeholder: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: endpoint == nil ? "mappin.and.ellipse" : "checkmark.circle.fill")
                    .foregroundStyle(endpoint == nil ? Color.secondary : Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(endpoint?.title(language: language) ?? placeholder)
                        .font(.headline).foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .customInfoCardSurface(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var results: some View {
        Text(localized("Suggested journeys", "建議行程", "建议行程")).font(.headline)
        if isPlanning {
            ProgressView(localized("Planning your journey…", "正在規劃行程…", "正在规划行程…"))
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if plannedJourneys.isEmpty && mtrJourneys.isEmpty && islandJourneys.isEmpty {
            ContentUnavailableView(
                localized("No journey found", "未找到行程", "未找到行程"),
                systemImage: "arrow.triangle.branch",
                description: Text(localized(
                    "Try another nearby origin or destination stop.",
                    "請嘗試選擇附近另一個出發地或目的地車站。",
                    "请尝试选择附近另一个出发地或目的地车站。"
                ))
            )
        } else {
            Picker(localized("Sort", "排序", "排序"), selection: $sortOption) {
                ForEach(PlannerSortOption.allCases) { option in
                    Text(option.title(language: language)).tag(option)
                }
            }
            .pickerStyle(.segmented)

            ForEach(sortedDisplayResults) { result in
                switch result {
                case let .bus(journey):
                    journeyCard(journey)
                case let .mtr(journey):
                    mtrJourneyCard(journey)
                case let .island(journey):
                    islandJourneyCard(journey)
                }
            }

            Label(
                localized(
                    "Walking routes are calculated by Apple Maps. Transit times and fares are estimates from the imported operator dataset; check live service information before departure.",
                    "步行路線由 Apple 地圖計算。交通時間及車費按已匯入的營辦商資料估算；出發前請查看即時服務資訊。",
                    "步行路线由 Apple 地图计算。交通时间及车费按已导入的运营商资料估算；出发前请查看实时服务信息。"
                ),
                systemImage: "info.circle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func journeyCard(_ result: UniversalPlannedJourney) -> some View {
        CustomInfoCardView(title: routeSummary(result)) {
            HStack(spacing: 8) {
                summaryValue(
                    localized("Duration", "時間", "时间"),
                    localized("\(result.totalMinutes) min", "\(result.totalMinutes) 分鐘", "\(result.totalMinutes) 分钟")
                )
                summaryValue(
                    localized("Walking", "步行", "步行"),
                    distanceText(result.totalWalkDistance)
                )
                summaryValue(
                    localized("Fare", "車費", "车费"),
                    fareText(result.totalFareCents)
                )
            }

            if result.accessWalkMinutes > 0,
               let boarding = result.legs.first?.boarding.stop {
                journeyStep(
                    icon: "figure.walk",
                    title: localized(
                        "Walk to \(boarding.displayName(for: language))",
                        "步行至\(boarding.displayName(for: language))",
                        "步行至\(boarding.displayName(for: language))"
                    ),
                    detail: "\(distanceText(result.accessWalkDistance)) · \(minutesText(result.accessWalkMinutes))"
                )
            }

            ForEach(Array(result.legs.enumerated()), id: \.element.id) { index, leg in
                if index > 0 {
                    Label(
                        localized("Transfer", "轉乘", "换乘"),
                        systemImage: "arrow.triangle.swap"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                    if result.transferWalkMinutes > 0 {
                        Text("\(distanceText(result.transferWalkDistance)) · \(minutesText(result.transferWalkMinutes))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                journeyStep(
                    icon: "bus.fill",
                    title: leg.journey.route?.number ?? localized("Transit", "公共交通", "公共交通"),
                    detail: "\(leg.boarding.stop?.displayName(for: language) ?? "") → \(leg.alighting.stop?.displayName(for: language) ?? "") · \(stopsText(leg.stopCount))"
                )
            }

            if result.egressWalkMinutes > 0,
               let alighting = result.legs.last?.alighting.stop {
                journeyStep(
                    icon: "figure.walk",
                    title: localized(
                        "Walk from \(alighting.displayName(for: language))",
                        "由\(alighting.displayName(for: language))步行前往目的地",
                        "由\(alighting.displayName(for: language))步行前往目的地"
                    ),
                    detail: "\(distanceText(result.egressWalkDistance)) · \(minutesText(result.egressWalkMinutes))"
                )
            }
        }
    }

    private func mtrJourneyCard(_ result: UniversalMTRJourney) -> some View {
        let feederNumber = result.feeder?.journey.route?.number
        let railLines = result.railJourney.legs.map { lineTitle($0.lineID) }
        let title = ([feederNumber].compactMap { $0 } + railLines).joined(separator: " → ")

        return CustomInfoCardView(title: title) {
            HStack(spacing: 8) {
                summaryValue(
                    localized("Duration", "時間", "时间"),
                    minutesText(result.totalMinutes)
                )
                summaryValue(
                    localized("Walking", "步行", "步行"),
                    distanceText(result.totalWalkDistance)
                )
                summaryValue(
                    localized("Fare", "車費", "车费"),
                    fareText(result.totalFareCents)
                )
            }

            if let feeder = result.feeder {
                if result.accessWalkDistance >= 25,
                   let boarding = feeder.boarding.stop {
                    journeyStep(
                        icon: "figure.walk",
                        title: localized(
                            "Walk to \(boarding.displayName(for: language))",
                            "步行至\(boarding.displayName(for: language))",
                            "步行至\(boarding.displayName(for: language))"
                        ),
                        detail: distanceText(result.accessWalkDistance)
                    )
                }
                journeyStep(
                    icon: "bus.fill",
                    title: feeder.journey.route?.number ?? localized("Bus", "巴士", "巴士"),
                    detail: "\(feeder.boarding.stop?.displayName(for: language) ?? "") → \(feeder.alighting.stop?.displayName(for: language) ?? "") · \(stopsText(feeder.stopCount))"
                )
                if result.transferWalkDistance >= 25 {
                    journeyStep(
                        icon: "figure.walk",
                        title: localized(
                            "Walk to \(stationName(result.originStation))",
                            "步行至\(stationName(result.originStation))",
                            "步行至\(stationName(result.originStation))"
                        ),
                        detail: distanceText(result.transferWalkDistance)
                    )
                }
            } else if result.accessWalkDistance >= 25 {
                journeyStep(
                    icon: "figure.walk",
                    title: localized(
                        "Walk to \(stationName(result.originStation))",
                        "步行至\(stationName(result.originStation))",
                        "步行至\(stationName(result.originStation))"
                    ),
                    detail: distanceText(result.accessWalkDistance)
                )
            }

            ForEach(Array(result.railJourney.legs.enumerated()), id: \.offset) { index, leg in
                if index > 0, let interchange = leg.stations.first {
                    Label(
                        localized(
                            "Interchange at \(stationName(interchange))",
                            "於\(stationName(interchange))轉線",
                            "在\(stationName(interchange))换乘"
                        ),
                        systemImage: "arrow.triangle.swap"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                }
                journeyStep(
                    icon: "tram.fill",
                    title: lineTitle(leg.lineID),
                    detail: "\(stationName(leg.stations.first ?? result.originStation)) → \(stationName(leg.stations.last ?? result.destinationStation)) · \(stopsText(leg.stopCount))"
                )
            }

            if result.egressWalkDistance >= 25 {
                journeyStep(
                    icon: "figure.walk",
                    title: localized(
                        "Walk from \(stationName(result.destinationStation))",
                        "由\(stationName(result.destinationStation))步行前往目的地",
                        "由\(stationName(result.destinationStation))步行前往目的地"
                    ),
                    detail: distanceText(result.egressWalkDistance)
                )
            }
        }
    }

    private func islandJourneyCard(_ result: UniversalIslandJourney) -> some View {
        CustomInfoCardView(title: islandRouteSummary(result)) {
            HStack(spacing: 8) {
                summaryValue(
                    localized("Duration", "時間", "时间"),
                    minutesText(result.totalMinutes)
                )
                summaryValue(
                    localized("Walking", "步行", "步行"),
                    distanceText(result.approach.totalWalkDistance)
                )
                summaryValue(
                    localized("Fare", "車費", "车费"),
                    localized("Check ferry fare", "請查閱渡輪票價", "请查阅渡轮票价")
                )
            }

            if let feeder = result.approach.feeder {
                if result.approach.accessWalkDistance >= 25,
                   let boarding = feeder.boarding.stop {
                    journeyStep(
                        icon: "figure.walk",
                        title: localized(
                            "Walk to \(boarding.displayName(for: language))",
                            "步行至\(boarding.displayName(for: language))",
                            "步行至\(boarding.displayName(for: language))"
                        ),
                        detail: distanceText(result.approach.accessWalkDistance)
                    )
                }
                journeyStep(
                    icon: "bus.fill",
                    title: feeder.journey.route?.number ?? localized("Bus", "巴士", "巴士"),
                    detail: "\(feeder.boarding.stop?.displayName(for: language) ?? "") → \(feeder.alighting.stop?.displayName(for: language) ?? "")"
                )
                if result.approach.transferWalkDistance >= 25 {
                    journeyStep(
                        icon: "figure.walk",
                        title: localized(
                            "Walk to \(stationName(result.approach.originStation))",
                            "步行至\(stationName(result.approach.originStation))",
                            "步行至\(stationName(result.approach.originStation))"
                        ),
                        detail: distanceText(result.approach.transferWalkDistance)
                    )
                }
            } else if result.approach.accessWalkDistance >= 25 {
                journeyStep(
                    icon: "figure.walk",
                    title: localized(
                        "Walk to \(stationName(result.approach.originStation))",
                        "步行至\(stationName(result.approach.originStation))",
                        "步行至\(stationName(result.approach.originStation))"
                    ),
                    detail: distanceText(result.approach.accessWalkDistance)
                )
            }

            ForEach(Array(result.approach.railJourney.legs.enumerated()), id: \.offset) { index, leg in
                if index > 0, let interchange = leg.stations.first {
                    Label(
                        localized(
                            "Interchange at \(stationName(interchange))",
                            "於\(stationName(interchange))轉線",
                            "在\(stationName(interchange))换乘"
                        ),
                        systemImage: "arrow.triangle.swap"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                }
                journeyStep(
                    icon: "tram.fill",
                    title: lineTitle(leg.lineID),
                    detail: "\(stationName(leg.stations.first ?? result.approach.originStation)) → \(stationName(leg.stations.last ?? result.approach.destinationStation))"
                )
            }

            journeyStep(
                icon: "figure.walk",
                title: localized("Walk to Central ferry pier", "步行至中環渡輪碼頭", "步行至中环渡轮码头"),
                detail: distanceText(result.approach.egressWalkDistance)
            )
            journeyStep(
                icon: "ferry.fill",
                title: "\(result.departureTime) · \(localized("Ferry", "渡輪", "渡轮"))",
                detail: result.destination.title(language: language)
            )
        }
    }

    private func stationName(_ station: MTRStation) -> String {
        switch language {
        case .english: station.english
        case .traditionalChinese: station.traditional
        case .simplifiedChinese: station.simplified
        }
    }

    private func lineTitle(_ lineID: String) -> String {
        switch lineID {
        case "TWL": localized("Tsuen Wan Line", "荃灣綫", "荃湾线")
        case "KTL": localized("Kwun Tong Line", "觀塘綫", "观塘线")
        case "ISL": localized("Island Line", "港島綫", "港岛线")
        case "SIL": localized("South Island Line", "南港島綫", "南港岛线")
        case "TKL": localized("Tseung Kwan O Line", "將軍澳綫", "将军澳线")
        case "TCL": localized("Tung Chung Line", "東涌綫", "东涌线")
        case "AEL": localized("Airport Express", "機場快綫", "机场快线")
        case "DRL": localized("Disneyland Resort Line", "迪士尼綫", "迪士尼线")
        case "EAL": localized("East Rail Line", "東鐵綫", "东铁线")
        case "TML": localized("Tuen Ma Line", "屯馬綫", "屯马线")
        default: lineID
        }
    }

    private func islandRouteSummary(_ result: UniversalIslandJourney) -> String {
        let feeder = result.approach.feeder?.journey.route?.number
        let lines = result.approach.railJourney.legs.map { lineTitle($0.lineID) }
        return ([feeder].compactMap { $0 } + lines + [localized("Ferry", "渡輪", "渡轮")])
            .joined(separator: " → ")
    }

    private func summaryValue(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .customInfoCardSurface(cornerRadius: 14)
    }

    private func journeyStep(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func routeSummary(_ result: UniversalPlannedJourney) -> String {
        result.legs.compactMap { $0.journey.route?.number }.joined(separator: " → ")
    }

    private func distanceText(_ distance: CLLocationDistance) -> String {
        if distance < 1_000 { return "\(Int(distance.rounded())) m" }
        return String(format: "%.1f km", distance / 1_000)
    }

    private func fareText(_ cents: Int?) -> String {
        guard let cents else { return "—" }
        return String(format: "HK$%.1f", Double(cents) / 100)
    }

    private func minutesText(_ minutes: Int) -> String {
        localized("\(minutes) min", "\(minutes) 分鐘", "\(minutes) 分钟")
    }

    private func stopsText(_ stops: Int) -> String {
        localized("\(stops) stops", "\(stops) 站", "\(stops) 站")
    }

    private func planJourneys() async {
        guard let origin, let destination else { return }
        searched = true
        isPlanning = true
        plannedJourneys = []
        mtrJourneys = []
        islandJourneys = []
        await Task.yield()

        async let resolvedOrigin = coordinate(for: origin)
        async let resolvedDestination = coordinate(for: destination)
        guard let originCoordinate = await resolvedOrigin,
              let destinationCoordinate = await resolvedDestination else {
            isPlanning = false
            return
        }

        if let islandDestination = destination.islandDestination {
            let approaches = UniversalMTRJourneyRouter.journeys(
                origin: originCoordinate,
                destination: islandDestination.ferryPierCoordinate,
                stops: stops,
                journeys: journeys,
                servicePeriod: servicePeriod,
                preferredOriginStationID: origin.originMTRStationID
            )
            islandJourneys = approaches.compactMap {
                UniversalIslandJourney.make(approach: $0, destination: islandDestination)
            }
            isPlanning = false
            return
        }

        let initialResults = UniversalJourneyRouter.journeys(
            from: origin,
            to: destination,
            originCoordinate: originCoordinate,
            destinationCoordinate: destinationCoordinate,
            stops: stops,
            journeys: journeys,
            servicePeriod: servicePeriod
        )
        let initialMTRResults = UniversalMTRJourneyRouter.journeys(
            origin: originCoordinate,
            destination: destinationCoordinate,
            stops: stops,
            journeys: journeys,
            servicePeriod: servicePeriod,
            preferredOriginStationID: origin.originMTRStationID,
            preferredDestinationStationID: destination.destinationMTRStationID
        )
        let hasSelectedRailTrip = origin.explicitMTRStationID != nil
            && destination.explicitMTRStationID != nil
            && !initialMTRResults.isEmpty
        plannedJourneys = hasSelectedRailTrip ? [] : initialResults
        mtrJourneys = initialMTRResults
        isPlanning = false

        for result in plannedJourneys.prefix(5) {
            guard !Task.isCancelled else { return }
            var refined = result

            if let boardingCoordinate = result.legs.first?.boarding.stop.map({
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }), result.accessWalkDistance >= 25,
               let route = try? await WalkingRouteService.route(
                    from: originCoordinate,
                    to: boardingCoordinate
               ) {
                refined.accessWalkDistance = route.distance
                refined.accessWalkMinutes = route.roundedMinutes
            }

            if let alightingCoordinate = result.legs.last?.alighting.stop.map({
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }), result.egressWalkDistance >= 25,
               let route = try? await WalkingRouteService.route(
                    from: alightingCoordinate,
                    to: destinationCoordinate
               ) {
                refined.egressWalkDistance = route.distance
                refined.egressWalkMinutes = route.roundedMinutes
            }

            if result.legs.count == 2,
               let transferFrom = result.legs[0].alighting.stop,
               let transferTo = result.legs[1].boarding.stop,
               result.transferWalkDistance >= 25,
               let route = try? await WalkingRouteService.route(
                    from: CLLocationCoordinate2D(
                        latitude: transferFrom.latitude,
                        longitude: transferFrom.longitude
                    ),
                    to: CLLocationCoordinate2D(
                        latitude: transferTo.latitude,
                        longitude: transferTo.longitude
                    )
               ) {
                refined.transferWalkDistance = route.distance
                refined.transferWalkMinutes = route.roundedMinutes
            }

            if let index = plannedJourneys.firstIndex(where: { $0.id == refined.id }) {
                if UniversalJourneyRouter.acceptsRefinedWalking(refined) {
                    plannedJourneys[index] = refined
                } else {
                    plannedJourneys.remove(at: index)
                }
            }
        }
    }

    private func coordinate(
        for endpoint: UniversalPlannerEndpoint
    ) async -> CLLocationCoordinate2D? {
        if let coordinate = endpoint.coordinate { return coordinate }

        // Map search can resolve an MTR station name to a similarly named
        // neighbourhood or road. Use imported operator stops at the station
        // as a deterministic local anchor instead.
        if case let .mtrStation(_, english, traditional, _) = endpoint,
           let coordinate = mtrStationAnchor(
               english: english,
               traditional: traditional
           ) {
            return coordinate
        }

        let englishName = endpoint.title(language: .english)
        let query: String
        switch endpoint {
        case .mtrStation:
            query = "\(englishName) MTR Station, Hong Kong"
        case .ferryPier:
            query = "\(englishName) Ferry Pier, Hong Kong"
        case .crossBoundary:
            query = "\(englishName), Hong Kong"
        case .transitStop, .place:
            return nil
        }
        return try? await PlannerPlaceResolver.coordinate(for: query)
    }

    private func mtrStationAnchor(
        english: String,
        traditional: String
    ) -> CLLocationCoordinate2D? {
        let englishNeedle = "\(english.lowercased()) station"
        let traditionalNeedle = "\(traditional)站"
        let matches = stops.filter { stop in
            stop.displayNameEnglish.lowercased().contains(englishNeedle)
                || stop.displayNameTraditional.contains(traditionalNeedle)
        }
        guard !matches.isEmpty else { return nil }

        // Stations commonly have several nearby stops. Averaging them keeps
        // one entrance or an opposite-side stop from shifting the anchor.
        let count = Double(matches.count)
        return CLLocationCoordinate2D(
            latitude: matches.reduce(0) { subtotal, stop in subtotal + stop.latitude } / count,
            longitude: matches.reduce(0) { subtotal, stop in subtotal + stop.longitude } / count
        )
    }

    private func servicePeriodTitle(_ period: PlannerServicePeriod) -> String {
        switch period {
        case .normal:
            localized("Normal service", "正常服務", "正常服务")
        case .overnight:
            localized("Overnight service", "通宵服務", "通宵服务")
        }
    }

    private func localized(_ english: String, _ traditional: String, _ simplified: String) -> String {
        switch language { case .english: english; case .traditionalChinese: traditional; case .simplifiedChinese: simplified }
    }

    private var originPlaceholder: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            localized(
                "Location unavailable — choose manually",
                "無法使用定位，請手動選擇",
                "无法使用定位，请手动选择"
            )
        case .notDetermined, .authorizedAlways, .authorizedWhenInUse:
            localized(
                "Finding your nearest stop…",
                "正在尋找最近車站…",
                "正在寻找最近车站…"
            )
        @unknown default:
            localized("Choose a stop or service", "選擇車站或服務", "选择车站或服务")
        }
    }

    private func selectNearestOriginIfNeeded() {
        guard !hasAutomaticallySelectedOrigin,
              origin == nil,
              let location = locationManager.location else { return }
        origin = stops
            .filter {
                CLLocationCoordinate2DIsValid(
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                )
            }
            .min {
                location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                    < location.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
            }
            .map(UniversalPlannerEndpoint.stop)
        hasAutomaticallySelectedOrigin = origin != nil
    }
}

private enum PlannerDisplayResult: Identifiable {
    case bus(UniversalPlannedJourney)
    case mtr(UniversalMTRJourney)
    case island(UniversalIslandJourney)

    var id: String {
        switch self {
        case let .bus(value): "bus-\(value.id)"
        case let .mtr(value): "mtr-\(value.id)"
        case let .island(value): "island-\(value.id)"
        }
    }

    var minutes: Int {
        switch self {
        case let .bus(value): value.totalMinutes
        case let .mtr(value): value.totalMinutes
        case let .island(value): value.totalMinutes
        }
    }

    var walkingDistance: CLLocationDistance {
        switch self {
        case let .bus(value): value.totalWalkDistance
        case let .mtr(value): value.totalWalkDistance
        case let .island(value): value.approach.totalWalkDistance
        }
    }

    var fareCents: Int? {
        switch self {
        case let .bus(value): value.totalFareCents
        case let .mtr(value): value.totalFareCents
        case .island: nil
        }
    }
}

private enum PlannerSortOption: String, CaseIterable, Identifiable {
    case fastest
    case leastWalking
    case lowestFare

    var id: Self { self }

    func title(language: TransitLanguage) -> String {
        switch self {
        case .fastest:
            plannerLocalized(language, "Fastest", "最快", "最快")
        case .leastWalking:
            plannerLocalized(language, "Shortest walk", "最短步行", "最短步行")
        case .lowestFare:
            plannerLocalized(language, "Lowest fare", "最低車費", "最低车费")
        }
    }
}

private struct UniversalEndpointPicker: View {
    let endpoints: [UniversalPlannerEndpoint]
    let sightseeingEndpoints: [UniversalPlannerEndpoint]
    let airportEndpoints: [UniversalPlannerEndpoint]
    let isOrigin: Bool
    let select: (UniversalPlannerEndpoint) -> Void
    @Environment(\.transitLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @AppStorage("favoriteStopIds") private var favoriteStopIDsValue = ""
    @AppStorage(MTRFavorite.storageKey) private var favoriteMTRStations = ""

    private var favoriteIDs: Set<String> {
        Set(favoriteStopIDsValue.split(separator: "\n").map(String.init))
    }

    private var favorites: [UniversalPlannerEndpoint] {
        let favoriteMTRIDs = Set(MTRFavorite.decode(favoriteMTRStations).map(\.stationID))
        return endpoints.filter { endpoint in
            switch endpoint {
            case let .transitStop(id, _, _, _, _, _):
                favoriteIDs.contains(id)
            case let .mtrStation(id, _, _, _):
                favoriteMTRIDs.contains(id)
            case .place:
                false
            default:
                false
            }
        }
    }

    private var mtrEndpoints: [UniversalPlannerEndpoint] {
        endpoints.filter {
            if case .mtrStation = $0 { return true }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    PlannerEndpointList(
                        title: plannerLocalized(language, "Favorites", "收藏", "收藏"),
                        endpoints: favorites,
                        emptyTitle: plannerLocalized(language, "No Favorites", "尚未有收藏", "尚未有收藏"),
                        emptyDescription: plannerLocalized(language,
                            "Save a bus stop or MTR station first.",
                            "請先收藏巴士站或港鐵站。",
                            "请先收藏巴士站或港铁站。"
                        ),
                        select: finishSelection
                    )
                } label: {
                    categoryRow(
                        plannerLocalized(language, "Favorites", "收藏", "收藏"),
                        systemImage: "bookmark.fill",
                        detail: "\(favorites.count)"
                    )
                }

                NavigationLink {
                    PlannerMTRLinePicker(
                        availableEndpoints: mtrEndpoints,
                        select: finishSelection
                    )
                } label: {
                    categoryRow(
                        plannerLocalized(language, "MTR stations", "港鐵站", "港铁站"),
                        systemImage: "tram.fill",
                        detail: plannerLocalized(language, "Choose line", "選擇路綫", "选择线路")
                    )
                }

                NavigationLink {
                    PlannerEndpointList(
                        title: plannerLocalized(language, "Airport", "機場", "机场"),
                        endpoints: sorted(airportEndpoints),
                        emptyTitle: plannerLocalized(language, "No Airport Stops", "未有機場車站", "未有机场车站"),
                        emptyDescription: plannerLocalized(language,
                            "Airport stops are unavailable in the current dataset.",
                            "目前資料中未有機場車站。",
                            "目前资料中未有机场车站。"
                        ),
                        select: finishSelection
                    )
                } label: {
                    categoryRow(
                        plannerLocalized(language, "Airport", "機場", "机场"),
                        systemImage: "airplane",
                        detail: "\(airportEndpoints.count)"
                    )
                }

                NavigationLink {
                    PlannerEndpointList(
                        title: plannerLocalized(language, "Sightseeing destinations", "觀光景點", "观光景点"),
                        endpoints: sorted(sightseeingEndpoints),
                        emptyTitle: plannerLocalized(language, "No Destinations", "未有景點", "未有景点"),
                        emptyDescription: plannerLocalized(language,
                            "Sightseeing stops are unavailable in the current dataset.",
                            "目前資料中未有觀光景點車站。",
                            "目前资料中未有观光景点车站。"
                        ),
                        select: finishSelection
                    )
                } label: {
                    categoryRow(
                        plannerLocalized(language, "Sightseeing destinations", "觀光景點", "观光景点"),
                        systemImage: "binoculars.fill",
                        detail: "\(sightseeingEndpoints.count)"
                    )
                }

                if isOrigin {
                    Section {
                        Text(plannerLocalized(language,
                            "Your nearest stop is selected automatically. Use this menu only when you want to change it.",
                            "系統會自動選擇最近車站；如要更改才使用此選單。",
                            "系统会自动选择最近车站；如要更改才使用此菜单。"
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(plannerLocalized(language, "Choose endpoint", "選擇地點", "选择地点"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func finishSelection(_ endpoint: UniversalPlannerEndpoint) {
        select(endpoint)
        dismiss()
    }

    private func sorted(_ values: [UniversalPlannerEndpoint]) -> [UniversalPlannerEndpoint] {
        values.sorted {
            $0.title(language: language).localizedStandardCompare(
                $1.title(language: language)
            ) == .orderedAscending
        }
    }

    private func categoryRow(_ title: String, systemImage: String, detail: String) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage).foregroundStyle(Color.accentColor)
        }
    }
}

private struct PlannerEndpointList: View {
    let title: String
    let endpoints: [UniversalPlannerEndpoint]
    let emptyTitle: String
    let emptyDescription: String
    let select: (UniversalPlannerEndpoint) -> Void
    @Environment(\.transitLanguage) private var language
    @State private var query = ""

    private var filtered: [UniversalPlannerEndpoint] {
        guard !query.isEmpty else { return endpoints }
        return endpoints.filter {
            "\($0.title(language: language)) \($0.subtitle(language: language))"
                .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if endpoints.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "mappin.slash",
                    description: Text(emptyDescription)
                )
            } else {
                List(filtered) { endpoint in
                    endpointRow(endpoint)
                }
                .searchable(text: $query, prompt: plannerLocalized(language, "Search", "搜尋", "搜索"))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func endpointRow(_ endpoint: UniversalPlannerEndpoint) -> some View {
        Button {
            select(endpoint)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(endpoint.title(language: language)).foregroundStyle(.primary)
                Text(endpoint.subtitle(language: language)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PlannerMTRLinePicker: View {
    let availableEndpoints: [UniversalPlannerEndpoint]
    let select: (UniversalPlannerEndpoint) -> Void
    @Environment(\.transitLanguage) private var language

    var body: some View {
        List(MTRLine.all) { line in
            NavigationLink {
                PlannerMTRStationPicker(
                    line: line,
                    availableEndpoints: availableEndpoints,
                    select: select
                )
            } label: {
                HStack(spacing: 12) {
                    Circle().fill(line.color).frame(width: 14, height: 14)
                    Text(LocalizedStringKey(line.title))
                }
            }
        }
        .navigationTitle(plannerLocalized(language, "MTR lines", "港鐵路綫", "港铁线路"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlannerMTRStationPicker: View {
    let line: MTRLine
    let availableEndpoints: [UniversalPlannerEndpoint]
    let select: (UniversalPlannerEndpoint) -> Void
    @Environment(\.transitLanguage) private var language
    @State private var stations: [MTRStation] = []
    @State private var failed = false

    var body: some View {
        Group {
            if failed {
                ContentUnavailableView(
                    plannerLocalized(language, "Unable to load stations", "無法載入車站", "无法载入车站"),
                    systemImage: "exclamationmark.triangle"
                )
            } else if stations.isEmpty {
                ProgressView()
            } else {
                List(stations) { station in
                    Button {
                        if let endpoint = availableEndpoints.first(where: { endpoint in
                            if case let .mtrStation(id, _, _, _) = endpoint {
                                return id == station.id
                            }
                            return false
                        }) {
                            select(endpoint)
                        }
                    } label: {
                        Text(stationName(station)).foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey(line.title))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: line.id) {
            do {
                let patterns = try MTRStations.load(line: line.id)
                var seen = Set<String>()
                stations = patterns
                    .flatMap(\.stations)
                    .filter { seen.insert($0.id).inserted }
            } catch {
                failed = true
            }
        }
    }

    private func stationName(_ station: MTRStation) -> String {
        switch language {
        case .english: station.english
        case .traditionalChinese: station.traditional
        case .simplifiedChinese: station.simplified
        }
    }
}

private func plannerLocalized(
    _ language: TransitLanguage,
    _ english: String,
    _ traditional: String,
    _ simplified: String
) -> String {
    switch language {
    case .english: english
    case .traditionalChinese: traditional
    case .simplifiedChinese: simplified
    }
}
