//
//  IslandJourneyPlannerView.swift
//  HK Way
//

import CoreLocation
import SwiftUI

struct IslandJourneyPlannerView: View {
    @Environment(\.transitLanguage) private var language
    @State private var mtrPlanner: MTRJourneyPlanner?
    @State private var originID = ""
    @State private var destination: IslandPlannerDestination = .yungShueWan
    @State private var isPickingOrigin = false
    @State private var journey: MTRPlannedJourney?
    @State private var walkingRoute: WalkingRoute?
    @State private var ferry: IslandFerryDeparture?
    @State private var mtrFare: MTRAdultFare?
    @State private var isPlanning = false
    @State private var errorMessage: String?

    private var origin: MTRStation? {
        mtrPlanner?.stations.first { $0.id == originID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(localized("Plan to an island destination", "規劃前往離島的行程", "规划前往离岛的行程"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button { isPickingOrigin = true } label: {
                    endpointCard(
                        title: localized("From MTR station", "出發港鐵站", "出发港铁站"),
                        value: origin.map(name) ?? localized("Choose a station", "選擇車站", "选择车站"),
                        symbol: "tram.fill"
                    )
                }
                .buttonStyle(.plain)

                Picker(localized("Island destination", "離島目的地", "离岛目的地"), selection: $destination) {
                    ForEach(IslandPlannerDestination.allCases) { destination in
                        Text(destination.title(language: language)).tag(destination)
                    }
                }
                .pickerStyle(.navigationLink)
                .padding(16)
                .customInfoCardSurface(cornerRadius: 22)

                Button {
                    Task { await planJourney() }
                } label: {
                    Label(localized("Find next journey", "尋找下一程", "寻找下一程"), systemImage: "arrow.triangle.branch")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .disabled(origin == nil || mtrPlanner == nil || isPlanning)

                if isPlanning {
                    ProgressView(localized("Planning journey…", "正在規劃行程⋯", "正在规划行程⋯"))
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if let journey, let walkingRoute, let ferry {
                    result(journey: journey, walkingRoute: walkingRoute, ferry: ferry)
                } else if let errorMessage {
                    ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
                }

                noteCard
            }
            .padding(16)
        }
        .navigationTitle(localized("Island Planner", "離島行程規劃", "离岛行程规划"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.gray.opacity(0.08).ignoresSafeArea())
        .sheet(isPresented: $isPickingOrigin) {
            StationPicker(stations: mtrPlanner?.stations ?? [], selection: $originID)
                .environment(\.transitLanguage, language)
        }
        .task {
            guard mtrPlanner == nil else { return }
            do {
                guard let url = Bundle.main.url(forResource: "MTRStations", withExtension: "csv") else { return }
                mtrPlanner = try MTRJourneyPlanner(
                    csv: String(contentsOf: url, encoding: .utf8),
                    lineIDs: MTRLine.all.map(\.id)
                )
            } catch {
                errorMessage = localized("Unable to load MTR stations.", "未能載入港鐵車站。", "未能载入港铁车站。")
            }
        }
    }

    @ViewBuilder private func result(
        journey: MTRPlannedJourney,
        walkingRoute: WalkingRoute,
        ferry: IslandFerryDeparture
    ) -> some View {
        Text(localized("Suggested journey", "建議行程", "建议行程"))
            .font(.headline)

        mtrJourneyCard(journey)

        CustomInfoCardView(title: localized("Walk", "步行", "步行")) {
            Text("Central Station → \(destination.ferryPierQuery.replacingOccurrences(of: ", Hong Kong", with: ""))")
                .font(.headline)
            Text("\(distance(walkingRoute.distance)) · \(walkingRoute.roundedMinutes) \(localized("min", "分鐘", "分钟"))")
                .foregroundStyle(.secondary)
        }

        CustomInfoCardView(title: localized("Ferry", "渡輪", "渡轮")) {
            Text("\(clock(ferry.departureMinutes)) · \(ferry.serviceDescription)")
                .font(.headline)
            Text(localized("Central → \(destination.title(language: language))", "中環 → \(destination.title(language: language))", "中环 → \(destination.title(language: language))"))
                .foregroundStyle(.secondary)
            if let minutes = ferry.referenceDurationMinutes {
                Text(localized("About \(minutes) min sailing time", "航程約 \(minutes) 分鐘", "航程约 \(minutes) 分钟"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func mtrJourneyCard(_ journey: MTRPlannedJourney) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("MTR", "港鐵", "港铁"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(name(origin!)) → Central")
                        .font(.title3.weight(.bold))
                }
                Spacer()
                if let mtrFare {
                    Text(price(mtrFare.octopus))
                        .font(.title3.weight(.bold))
                }
            }

            Text(localized(
                "\(journey.stops) stops · \(journey.changes) changes",
                "\(journey.stops) 站 · \(journey.changes) 次轉線",
                "\(journey.stops) 站 · \(journey.changes) 次换线"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if journey.legs.isEmpty {
                Label(
                    localized("You are already at Central.", "你已身處中環站。", "你已身处中环站。"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)
            }

            ForEach(Array(journey.legs.enumerated()), id: \.offset) { index, leg in
                if index > 0, let interchange = leg.stations.first {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.tint)
                            .frame(width: 22)
                        Text(localized(
                            "Change trains at \(name(interchange))",
                            "在 \(name(interchange)) 站轉線",
                            "在 \(name(interchange)) 站换线"
                        ))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    }
                    .padding(.vertical, 2)
                }

                let startingAt = journey.legs.prefix(index).reduce(1) {
                    $0 + max(0, $1.stations.count - 1)
                }
                mtrLegRow(leg, startingAt: startingAt)
            }
        }
        .padding(18)
        .customInfoCardSurface(cornerRadius: 22)
    }

    @ViewBuilder private func mtrLegRow(
        _ leg: MTRJourneyLeg,
        startingAt: Int
    ) -> some View {
        if let terminus = leg.pattern.stations.last {
            let line = MTRLine.all.first(where: { $0.id == leg.lineID })
            let color = line?.color ?? .accentColor

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let line {
                        MTRInterchangeBadge(line: line)
                    } else {
                        Text(lineTitle(for: leg))
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                }

                Text(localized(
                    "Towards \(name(terminus))",
                    "往 \(name(terminus))",
                    "往 \(name(terminus))"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    if leg.stations.count > 2, let first = leg.stations.first, let last = leg.stations.last {
                        railStationRow(
                            first,
                            sequence: startingAt,
                            color: color,
                            hasTopLine: false,
                            hasBottomLine: true
                        )
                        railStationRow(
                            last,
                            sequence: startingAt + leg.stations.count - 1,
                            color: color,
                            hasTopLine: true,
                            hasBottomLine: false
                        )
                    } else {
                        ForEach(Array(leg.stations.enumerated()), id: \.offset) { index, station in
                            railStationRow(
                                station,
                                sequence: startingAt + index,
                                color: color,
                                hasTopLine: index > 0,
                                hasBottomLine: index < leg.stations.count - 1
                            )
                        }
                    }
                }
            }
        }
    }

    private func railStationRow(
        _ station: MTRStation,
        sequence: Int,
        color: Color,
        hasTopLine: Bool,
        hasBottomLine: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Text(sequence, format: .number)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)

            ZStack {
                if hasTopLine {
                    Rectangle()
                        .fill(color)
                        .frame(width: 3, height: 27)
                        .offset(y: -13.5)
                }
                if hasBottomLine {
                    Rectangle()
                        .fill(color)
                        .frame(width: 3, height: 27)
                        .offset(y: 13.5)
                }
                Circle()
                    .strokeBorder(color, lineWidth: 3)
                    .background(Circle().fill(Color(uiColor: .systemBackground)))
                    .frame(width: 15, height: 15)
            }
            .frame(width: 15, height: 52)

            Text(name(station))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(localized("Planner notes", "行程規劃注意事項", "行程规划注意事项"), systemImage: "info.circle")
                .font(.headline)
            Text(localized(
                "Walking distance and time use Apple Maps. Ferry departures are published schedules; Sunday is treated as the Sunday/public-holiday timetable. Check operator notices and fares before travel.",
                "步行距離及時間由 Apple 地圖計算。渡輪班次採用已公布時間表；星期日會使用星期日／公眾假期時間表。出發前請查閱營辦商公告及票價。",
                "步行距离及时间由 Apple 地图计算。渡轮班次采用已公布时间表；星期日会使用星期日／公众假期时间表。出发前请查阅运营商公告及票价。"
            ))
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(16)
        .customInfoCardSurface(cornerRadius: 22)
    }

    private func planJourney() async {
        guard let mtrPlanner, let origin else { return }
        let planned: MTRPlannedJourney
        if origin.id == "CEN" {
            planned = MTRPlannedJourney(legs: [])
        } else if let result = mtrPlanner.plan(from: origin.id, to: "CEN") {
            planned = result
        } else {
            errorMessage = localized("No supported MTR journey was found.", "找不到可用的港鐵行程。", "找不到可用的港铁行程。")
            return
        }
        isPlanning = true
        errorMessage = nil
        journey = nil
        defer { isPlanning = false }
        do {
            // These are the pedestrian anchors for the Central MTR interchange
            // and each named ferry pier. Search results can resolve to a road or
            // a similarly named place, producing an unusable detour.
            let centralMTRExit = CLLocationCoordinate2D(
                latitude: 22.28190,
                longitude: 114.15869
            )
            let walk = try await WalkingRouteService.route(
                from: centralMTRExit,
                to: destination.ferryPierCoordinate
            )
            let railMinutes = max(4, planned.stops * 2 + planned.changes * 3)
            let readyAt = Date.now.addingTimeInterval(TimeInterval((railMinutes + walk.roundedMinutes + 5) * 60))
            guard let departure = try IslandFerrySchedule.nextDeparture(to: destination, after: readyAt) else {
                errorMessage = localized("No later ferry is listed for today.", "今日沒有較後的渡輪班次。", "今日没有较后的渡轮班次。")
                return
            }
            journey = planned
            walkingRoute = walk
            ferry = departure
            mtrFare = fare(from: origin.id, to: "CEN")
        } catch {
            errorMessage = localized("Unable to plan this journey right now.", "暫時未能規劃此行程。", "暂时未能规划此行程。")
        }
    }

    private func fare(from: String, to: String) -> MTRAdultFare? {
        guard let stations = try? MTRStations.loadFareStations(airportExpress: false),
              let origin = stations.first(where: { $0.id == from }),
              let destination = stations.first(where: { $0.id == to }),
              let fares = try? MTRFares.load(airportExpress: false) else { return nil }
        return fares[MTRFares.key(from: origin.fareID, to: destination.fareID)]
    }

    private func endpointCard(title: String, value: String, symbol: String) -> some View {
        HStack {
            Image(systemName: symbol).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(16)
        .customInfoCardSurface(cornerRadius: 22)
    }

    private func localized(_ english: String, _ traditional: String, _ simplified: String) -> String {
        switch language { case .english: english; case .traditionalChinese: traditional; case .simplifiedChinese: simplified }
    }

    private func name(_ station: MTRStation) -> String {
        switch language { case .english: station.english; case .traditionalChinese: station.traditional; case .simplifiedChinese: station.simplified }
    }

    private func lineTitle(for leg: MTRJourneyLeg) -> String {
        MTRLine.all.first(where: { $0.id == leg.lineID })?.title ?? leg.lineID
    }

    private func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
    private func distance(_ meters: Double) -> String { meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters.rounded())) m" }
    private func price(_ value: Decimal) -> String { "HK$" + NSDecimalNumber(decimal: value).stringValue }
}

private struct StationPicker: View {
    let stations: [MTRStation]
    @Binding var selection: String
    @Environment(\.transitLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(filteredStations) { station in
                Button {
                    selection = station.id
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(name(station)).foregroundStyle(.primary)
                        if language != .english { Text(station.english).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search MTR stations")
            .navigationTitle("Choose MTR station")
        }
    }

    private var filteredStations: [MTRStation] {
        guard !query.isEmpty else { return stations }
        return stations.filter { "\($0.english) \($0.traditional) \($0.simplified)".localizedCaseInsensitiveContains(query) }
    }
    private func name(_ station: MTRStation) -> String {
        switch language { case .english: station.english; case .traditionalChinese: station.traditional; case .simplifiedChinese: station.simplified }
    }
}
