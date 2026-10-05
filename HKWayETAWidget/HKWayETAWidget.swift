import AppIntents
import SwiftUI
import WidgetKit

private struct WidgetSnapshot: Codable, Identifiable, Sendable {
    let id: String
    let routeId: String
    let routeNumber: String
    let destinationEnglish: String
    let destinationTraditional: String
    let destinationSimplified: String
    let stopEnglish: String
    let stopTraditional: String
    let stopSimplified: String
    let operatorIds: [String]
    let arrivalDates: [Date]
    let updatedAt: Date
    let etaReferences: [WidgetETAReference]?
    var refreshFailed: Bool? = nil

    var routeDirectionId: String {
        "\(routeId)|\(destinationEnglish)"
    }

    var localizedDestination: String {
        switch WidgetLanguage.current {
        case .english: destinationEnglish
        case .traditionalChinese: destinationTraditional
        case .simplifiedChinese: destinationSimplified
        }
    }

    var localizedStop: String {
        switch WidgetLanguage.current {
        case .english: stopEnglish
        case .traditionalChinese: stopTraditional
        case .simplifiedChinese: stopSimplified
        }
    }
}

private struct WidgetETAReference: Codable, Sendable {
    let operatorId: String
    let operatorStopId: String
    let operatorServiceType: String
    let operatorDirection: String
}

private enum WidgetSnapshotStore {
    static let appGroupId = "group.com.kenwong.hkway"
    static let snapshotsKey = "etaWidgetSnapshots"
    static let languageKey = "etaWidgetLanguage"
    static let accessTierKey = "appAccessTier.v1"
    static let freeFavoriteKey = "freeWidgetFavoriteId.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    private static var hasFullAccess: Bool {
        defaults?.string(forKey: accessTierKey) == "full"
    }

    // Separate per-stop cache: app catalog exports must not erase fetched ETA.
    static func cachedSnapshot(for snapshot: WidgetSnapshot) -> WidgetSnapshot {
        guard
            let data = UserDefaults(suiteName: appGroupId)?
                .data(forKey: "etaWidgetCache|\(snapshot.id)"),
            let cached = try? JSONDecoder().decode(WidgetSnapshot.self, from: data),
            cached.id == snapshot.id,
            cached.updatedAt > snapshot.updatedAt
                || snapshot.arrivalDates.isEmpty
        else { return snapshot }
        return cached
    }

    static func cache(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupId)?
            .set(data, forKey: "etaWidgetCache|\(snapshot.id)")
    }

    static func load() -> [WidgetSnapshot] {
        guard
            let data = UserDefaults(suiteName: appGroupId)?
                .data(forKey: snapshotsKey),
            let snapshots = try? JSONDecoder().decode(
                [WidgetSnapshot].self,
                from: data
            )
        else {
            return []
        }

        return snapshots
    }

    static func selectableSnapshots() -> [WidgetSnapshot] {
        load()
    }

    static func recordFreeSelection(_ snapshotId: String) {
        // Kept for compatibility with existing widget call sites. All saved
        // snapshots can now be selected without a purchase.
    }
}

private enum WidgetLanguage: String {
    case english = "English"
    case traditionalChinese = "繁體中文"
    case simplifiedChinese = "简体中文"

    static var current: WidgetLanguage {
        guard
            let value = UserDefaults(
                suiteName: WidgetSnapshotStore.appGroupId
            )?.string(forKey: WidgetSnapshotStore.languageKey)
        else {
            return .english
        }

        return WidgetLanguage(rawValue: value) ?? .english
    }

    var previewText: String {
        switch self {
        case .english: "Preview"
        case .traditionalChinese: "預覽"
        case .simplifiedChinese: "预览"
        }
    }

    var refreshText: String {
        switch self {
        case .english: "Open HK Way to refresh"
        case .traditionalChinese: "開啟 HK Way 以重新整理"
        case .simplifiedChinese: "打开 HK Way 以刷新"
        }
    }

    var emptyTitle: String {
        switch self {
        case .english: "Favorite ETA"
        case .traditionalChinese: "收藏到站時間"
        case .simplifiedChinese: "收藏到站时间"
        }
    }

    var emptyMessage: String {
        switch self {
        case .english:
            "Open HK Way and refresh a favorite route first."
        case .traditionalChinese:
            "請先開啟 HK Way 並重新整理收藏路線。"
        case .simplifiedChinese:
            "请先打开 HK Way 并刷新收藏路线。"
        }
    }

    var noETAText: String {
        switch self {
        case .english: "No ETA"
        case .traditionalChinese: "暫無到站時間"
        case .simplifiedChinese: "暂无到站时间"
        }
    }

    var outdatedText: String {
        switch self {
        case .english: "Outdated · retry refresh"
        case .traditionalChinese: "資料未更新・請重試"
        case .simplifiedChinese: "数据未更新・请重试"
        }
    }

    var locale: Locale {
        switch self {
        case .english: Locale(identifier: "en_HK")
        case .traditionalChinese: Locale(identifier: "zh_Hant_HK")
        case .simplifiedChinese: Locale(identifier: "zh_Hans_HK")
        }
    }
}

struct WidgetRouteEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Route Direction"
    )
    static let defaultQuery = WidgetRouteQuery()

    let id: String
    let routeNumber: String
    let destination: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(routeNumber)",
            subtitle: "\(destination)"
        )
    }
}

struct WidgetRouteQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws
        -> [WidgetRouteEntity] {
        Self.allEntities.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WidgetRouteEntity] {
        Self.selectableEntities
    }

    static var allEntities: [WidgetRouteEntity] {
        entities(from: WidgetSnapshotStore.load())
    }

    static var selectableEntities: [WidgetRouteEntity] {
        entities(from: WidgetSnapshotStore.selectableSnapshots())
    }

    private static func entities(
        from snapshots: [WidgetSnapshot]
    ) -> [WidgetRouteEntity] {
        var seen = Set<String>()

        return snapshots.compactMap { snapshot in
            let id = snapshot.routeDirectionId
            guard seen.insert(id).inserted else {
                return nil
            }

            return WidgetRouteEntity(
                id: id,
                routeNumber: snapshot.routeNumber,
                destination: snapshot.localizedDestination
            )
        }
    }
}

struct FavoriteETAEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Boarding Stop"
    )
    static let defaultQuery = FavoriteETAQuery()

    let id: String
    let routeDirectionId: String
    let routeNumber: String
    let destination: String
    let stopName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(stopName)",
            subtitle: "\(routeNumber) · \(destination)"
        )
    }
}

struct FavoriteETAQuery: EntityQuery {
    @IntentParameterDependency<SelectFavoriteETAIntent>(\.$route)
    private var intent

    func entities(for identifiers: [String]) async throws
        -> [FavoriteETAEntity] {
        Self.allEntities.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [FavoriteETAEntity] {
        guard let routeDirectionId = intent?.route.id else {
            return []
        }

        return Self.selectableEntities.filter {
            $0.routeDirectionId == routeDirectionId
        }
    }

    static var allEntities: [FavoriteETAEntity] {
        entities(from: WidgetSnapshotStore.load())
    }

    static var selectableEntities: [FavoriteETAEntity] {
        entities(from: WidgetSnapshotStore.selectableSnapshots())
    }

    private static func entities(
        from snapshots: [WidgetSnapshot]
    ) -> [FavoriteETAEntity] {
        snapshots.map {
            FavoriteETAEntity(
                id: $0.id,
                routeDirectionId: $0.routeDirectionId,
                routeNumber: $0.routeNumber,
                destination: $0.localizedDestination,
                stopName: $0.localizedStop
            )
        }
    }
}

struct SelectFavoriteETAIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Favorite ETA"
    static let description = IntentDescription(
        "Choose a favorite route and boarding stop."
    )

    @Parameter(title: "Route and Destination")
    var route: WidgetRouteEntity?

    @Parameter(title: "Boarding Stop")
    var favorite: FavoriteETAEntity?
}

struct RefreshTransitETAIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh ETA"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "TransitGoETAWidget")
        return .result()
    }
}

private struct TransitGoETAEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let boardSnapshots: [WidgetSnapshot]

    init(
        date: Date,
        snapshot: WidgetSnapshot?,
        boardSnapshots: [WidgetSnapshot] = []
    ) {
        self.date = date
        self.snapshot = snapshot
        self.boardSnapshots = boardSnapshots
    }
}

private enum WidgetETAFetcher {
    static func refresh(_ snapshot: WidgetSnapshot) async -> WidgetSnapshot {
        guard let references = snapshot.etaReferences, !references.isEmpty else {
            return snapshot
        }

        var arrivals: [Date] = []
        var successfulRequests = 0
        var failedRequests = 0
        for reference in references {
            do {
                let dates = try await fetch(
                    reference: reference,
                    routeNumber: snapshot.routeNumber
                )
                successfulRequests += 1
                arrivals.append(contentsOf: dates)
            } catch {
                failedRequests += 1
            }
        }

        guard successfulRequests > 0 else {
            var fallback = WidgetSnapshotStore.cachedSnapshot(for: snapshot)
            fallback.refreshFailed = true
            return fallback
        }

        let futureArrivals = Array(
            Set(arrivals.filter { $0 >= Date() })
                .sorted()
                .prefix(3)
        )

        var refreshed = WidgetSnapshot(
            id: snapshot.id,
            routeId: snapshot.routeId,
            routeNumber: snapshot.routeNumber,
            destinationEnglish: snapshot.destinationEnglish,
            destinationTraditional: snapshot.destinationTraditional,
            destinationSimplified: snapshot.destinationSimplified,
            stopEnglish: snapshot.stopEnglish,
            stopTraditional: snapshot.stopTraditional,
            stopSimplified: snapshot.stopSimplified,
            operatorIds: snapshot.operatorIds,
            arrivalDates: futureArrivals,
            updatedAt: .now,
            etaReferences: snapshot.etaReferences
        )
        refreshed.refreshFailed = failedRequests > 0
        if failedRequests == 0 {
            WidgetSnapshotStore.cache(refreshed)
        }
        return refreshed
    }

    private static func fetch(
        reference: WidgetETAReference,
        routeNumber: String
    ) async throws -> [Date] {
        switch reference.operatorId {
        case "KMB", "LWB":
            return try await fetchKMB(
                reference: reference,
                routeNumber: routeNumber
            )
        case "CTB":
            return try await fetchCTB(
                reference: reference,
                routeNumber: routeNumber
            )
        default:
            throw URLError(.unsupportedURL)
        }
    }

    private static func fetchKMB(
        reference: WidgetETAReference,
        routeNumber: String
    ) async throws -> [Date] {
        guard
            let serviceType = Int(reference.operatorServiceType),
            let url = URL(
                string: "https://data.etabus.gov.hk/v1/transport/kmb/eta/\(reference.operatorStopId)/\(routeNumber)/\(serviceType)"
            )
        else {
            throw URLError(.badURL)
        }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let records = try JSONDecoder().decode(KMBResponse.self, from: data)
        return records.data.compactMap { record in
            guard record.direction == reference.operatorDirection else {
                return nil
            }
            return record.eta.flatMap(ISO8601DateFormatter().date(from:))
        }
    }

    private static func fetchCTB(
        reference: WidgetETAReference,
        routeNumber: String
    ) async throws -> [Date] {
        guard let url = URL(
            string: "https://rt.data.gov.hk/v1/transport/citybus-nwfb/eta/CTB/\(reference.operatorStopId)/\(routeNumber)"
        ) else {
            throw URLError(.badURL)
        }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let records = try JSONDecoder().decode(CTBResponse.self, from: data)
        return records.data.compactMap { record in
            guard record.direction == reference.operatorDirection else { return nil }
            return record.eta.flatMap(ISO8601DateFormatter().date(from:))
        }
    }

    private struct KMBResponse: Decodable {
        let data: [KMBRecord]
    }

    private struct KMBRecord: Decodable {
        let direction: String?
        let eta: String?

        enum CodingKeys: String, CodingKey {
            case direction = "dir"
            case eta
        }
    }

    private struct CTBResponse: Decodable {
        let data: [CTBRecord]
    }

    private struct CTBRecord: Decodable {
        let eta: String?
        let direction: String?

        enum CodingKeys: String, CodingKey {
            case eta
            case direction = "dir"
        }
    }
}

private struct TransitGoETAProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TransitGoETAEntry {
        TransitGoETAEntry(
            date: .now,
            snapshot: WidgetSnapshot(
                id: "preview",
                routeId: "preview",
                routeNumber: "268X",
                destinationEnglish: "West Kowloon Station",
                destinationTraditional: "高鐵西九龍站",
                destinationSimplified: "高铁西九龙站",
                stopEnglish: "Hung Shui Kiu Station",
                stopTraditional: "洪水橋站",
                stopSimplified: "洪水桥站",
                operatorIds: ["KMB"],
                arrivalDates: [
                    .now.addingTimeInterval(5 * 60),
                    .now.addingTimeInterval(16 * 60),
                    .now.addingTimeInterval(28 * 60)
                ],
                updatedAt: .now,
                etaReferences: nil
            )
        )
    }

    func snapshot(
        for configuration: SelectFavoriteETAIntent,
        in context: Context
    ) async -> TransitGoETAEntry {
        if let entry = await entry(for: configuration) {
            return entry
        }

        return context.isPreview
            ? placeholder(in: context)
            : TransitGoETAEntry(date: .now, snapshot: nil)
    }

    func timeline(
        for configuration: SelectFavoriteETAIntent,
        in context: Context
    ) async -> Timeline<TransitGoETAEntry> {
        guard let entry = await entry(for: configuration) else {
            return Timeline(
                entries: [TransitGoETAEntry(date: .now, snapshot: nil)],
                policy: .after(.now.addingTimeInterval(30 * 60))
            )
        }

        let transitionEntries = entry.snapshot?.arrivalDates
            .filter { $0 > entry.date }
            .map {
                TransitGoETAEntry(
                    date: $0.addingTimeInterval(1),
                    snapshot: entry.snapshot,
                    boardSnapshots: entry.boardSnapshots
                )
            } ?? []
        // Request fresh predictions without waiting for the last arrival.
        // WidgetKit may defer this request according to its refresh budget.
        let refreshDate = entry.date.addingTimeInterval(5 * 60)
        return Timeline(
            entries: [entry] + transitionEntries,
            policy: .after(refreshDate)
        )
    }

    private func entry(
        for configuration: SelectFavoriteETAIntent
    ) async -> TransitGoETAEntry? {
        let snapshots = WidgetSnapshotStore.load()
        let snapshot: WidgetSnapshot?
        if let favorite = configuration.favorite {
            // Never silently substitute another stop or the opposite direction.
            snapshot = snapshots.first {
                $0.id == favorite.id
                    && (configuration.route == nil
                        || $0.routeDirectionId == configuration.route?.id)
            }
        } else if let route = configuration.route {
            snapshot = snapshots.first { $0.routeDirectionId == route.id }
        } else {
            snapshot = snapshots.first
        }

        guard let snapshot else {
            return nil
        }

        WidgetSnapshotStore.recordFreeSelection(snapshot.id)
        let refreshed = await WidgetETAFetcher.refresh(snapshot)
        var boardSnapshots = [refreshed]
        for candidate in snapshots where candidate.id != refreshed.id {
            boardSnapshots.append(WidgetSnapshotStore.cachedSnapshot(for: candidate))
            if boardSnapshots.count == 3 { break }
        }
        return TransitGoETAEntry(
            date: .now,
            snapshot: refreshed,
            boardSnapshots: boardSnapshots
        )
    }
}

private struct TransitGoETAWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TransitGoETAEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(snapshot)
                    .widgetURL(widgetURL(for: snapshot.routeId))
            } else {
                unavailableContent
            }
        }
        .unredacted()
        .foregroundStyle(.primary)
        .containerBackground(for: .widget) {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                operatorColor.opacity(0.12)
            }
        }
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        if family == .systemLarge {
            largeContent(primary: snapshot)
        } else {
            compactContent(snapshot)
        }
    }

    private func largeContent(primary: WidgetSnapshot) -> some View {
        let arrivals = futureArrivals(primary)
        let supportingSnapshots = secondarySnapshots(excluding: primary.id)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(boardTitle, systemImage: "bus.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(
                    primary.id == "preview"
                        ? WidgetLanguage.current.previewText
                        : operatorName(primary.operatorIds.first)
                )
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Self.color(for: primary.operatorIds.first ?? ""), in: Capsule())
                .foregroundStyle(operatorTextColor)
            }

            HStack(alignment: .center, spacing: 12) {
                Text(primary.routeNumber)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(minWidth: 64, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(primary.localizedDestination)
                        .font(.headline)
                        .lineLimit(1)
                    Text(primary.localizedStop)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let nextArrival = arrivals.first {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(timerInterval: entry.date...nextArrival, countsDown: true, showsHours: false)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(nextArrival, style: .time)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(arrivals.dropFirst().prefix(2).map { scheduledArrivalText($0, relativeTo: entry.date) }.joined(separator: "  ·  "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(WidgetLanguage.current.noETAText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if supportingSnapshots.isEmpty {
                Text(otherFavoritesText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(supportingSnapshots) { snapshot in
                    HStack(spacing: 8) {
                        Text(snapshot.routeNumber)
                            .font(.headline.bold())
                            .monospacedDigit()
                            .frame(width: 48, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(snapshot.localizedDestination)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(snapshot.localizedStop)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        if let arrival = futureArrivals(snapshot).first {
                            Text(compactArrivalText(arrival))
                                .font(.headline.bold())
                                .monospacedDigit()
                        } else {
                            Text(WidgetLanguage.current.noETAText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                    Text(primary.updatedAt, style: .time)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                if isOutdated(primary) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .accessibilityLabel(WidgetLanguage.current.outdatedText)
                }
                Spacer()
                refreshButton
            }
        }
    }

    private func secondarySnapshots(excluding primaryID: String) -> [WidgetSnapshot] {
        var result: [WidgetSnapshot] = []
        for snapshot in entry.boardSnapshots where snapshot.id != primaryID {
            result.append(snapshot)
            if result.count == 2 { break }
        }
        return result
    }

    private var boardTitle: String {
        switch WidgetLanguage.current {
        case .english: "Favourite departures"
        case .traditionalChinese: "收藏班次"
        case .simplifiedChinese: "收藏班次"
        }
    }

    private var otherFavoritesText: String {
        switch WidgetLanguage.current {
        case .english: "Add more favourites in HK Way to fill this board."
        case .traditionalChinese: "在 HK Way 加入更多收藏路線，即可顯示更多班次。"
        case .simplifiedChinese: "在 HK Way 加入更多收藏路线，即可显示更多班次。"
        }
    }

    private func compactContent(_ snapshot: WidgetSnapshot) -> some View {
        let arrivals = futureArrivals(snapshot)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.routeNumber)
                    .font(family == .systemSmall ? .headline.bold() : .title3.bold())
                Spacer()
                Text(
                    snapshot.id == "preview"
                        ? WidgetLanguage.current.previewText
                        : operatorName(snapshot.operatorIds.first)
                )
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(operatorColor, in: Capsule())
                    .foregroundStyle(operatorTextColor)
            }

            Text(snapshot.localizedDestination)
                .font(
                    family == .systemSmall
                        ? .caption.weight(.semibold)
                        : .subheadline.weight(.semibold)
                )
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Text(snapshot.localizedStop)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if family == .systemSmall {
                HStack {
                    if isOutdated(snapshot) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                            .accessibilityLabel(WidgetLanguage.current.outdatedText)
                    }
                    if let arrival = arrivals.first {
                        Text(compactArrivalText(arrival))
                            .font(.subheadline.bold())
                            .monospacedDigit()
                    } else {
                        Text(WidgetLanguage.current.noETAText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    refreshButton
                }
            } else if arrivals.isEmpty {
                Text(WidgetLanguage.current.noETAText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        if arrivals.indices.contains(index) {
                            let arrival = arrivals[index]

                            if index == 0 {
                                HStack(spacing: 3) {
                                    Text(
                                        timerInterval:
                                            entry.date...arrival,
                                        countsDown: true,
                                        showsHours: false
                                    )

                                    Text(
                                        "(\(Self.clockFormatter.string(from: arrival)))"
                                    )
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Text(
                                    scheduledArrivalText(
                                        arrival,
                                        relativeTo: entry.date
                                    )
                                )
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            Text(WidgetLanguage.current.noETAText)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
            }

            if family != .systemSmall {
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                        Text(snapshot.updatedAt, style: .time)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    if isOutdated(snapshot) {
                        Text(WidgetLanguage.current.outdatedText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer()
                    refreshButton
                }
            }
        }
    }

    private var refreshButton: some View {
        Button(intent: RefreshTransitETAIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(refreshAccessibilityLabel)
    }

    private func isOutdated(_ snapshot: WidgetSnapshot) -> Bool {
        snapshot.refreshFailed == true
            || entry.date.timeIntervalSince(snapshot.updatedAt) > 15 * 60
    }

    private var refreshAccessibilityLabel: String {
        switch WidgetLanguage.current {
        case .english: "Refresh ETA"
        case .traditionalChinese: "重新整理到站時間"
        case .simplifiedChinese: "刷新到站时间"
        }
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "bus.fill")
                .font(.title2)
            Text(WidgetLanguage.current.emptyTitle)
                .font(.headline)
            Text(WidgetLanguage.current.emptyMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func futureArrivals(_ snapshot: WidgetSnapshot) -> [Date] {
        snapshot.arrivalDates.filter { $0 >= entry.date }.sorted()
    }

    private func compactArrivalText(_ arrival: Date) -> String {
        let minutes = max(
            0,
            Int(arrival.timeIntervalSince(entry.date) / 60)
        )

        switch WidgetLanguage.current {
        case .traditionalChinese, .simplifiedChinese:
            return minutes == 0 ? "即到" : "\(minutes) 分"
        case .english:
            return minutes == 0 ? "Due" : "\(minutes) min"
        }
    }

    private func scheduledArrivalText(
        _ arrival: Date,
        relativeTo date: Date
    ) -> String {
        let minutes = max(
            0,
            Int(arrival.timeIntervalSince(date) / 60)
        )
        let clockTime = Self.clockFormatter.string(from: arrival)

        switch WidgetLanguage.current {
        case .english:
            return "\(minutes)min (\(clockTime))"
        case .traditionalChinese, .simplifiedChinese:
            return "\(minutes)分（\(clockTime)）"
        }
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func widgetURL(for routeId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "hkway"
        components.host = "route"
        components.path = "/\(routeId)"
        return components.url
    }

    private var operatorColor: Color {
        guard let operatorId = entry.snapshot?.operatorIds.first else {
            return .blue
        }
        return Self.color(for: operatorId)
    }

    private var operatorTextColor: Color {
        guard let operatorId = entry.snapshot?.operatorIds.first else {
            return .white
        }
        return ["CTB", "NLB"].contains(operatorId) ? .black : .white
    }

    private func operatorName(_ operatorId: String?) -> String {
        guard let operatorId else {
            return "HK Way"
        }

        guard WidgetLanguage.current != .english else {
            return operatorId == "LRTFeeder" ? "MTR" : operatorId
        }

        let traditionalNames = [
            "KMB": "九巴",
            "LWB": "龍運",
            "CTB": "城巴",
            "NLB": "嶼巴",
            "GMB": "專線小巴",
            "LRTFeeder": "港鐵",
            "PI": "居民巴士",
            "DB": "愉景灣",
            "XB": "過境巴士",
            "TRAM": "香港電車"
        ]
        let simplifiedNames = [
            "KMB": "九巴",
            "LWB": "龙运",
            "CTB": "城巴",
            "NLB": "屿巴",
            "GMB": "专线小巴",
            "LRTFeeder": "港铁",
            "PI": "居民巴士",
            "DB": "愉景湾",
            "XB": "过境巴士",
            "TRAM": "香港电车"
        ]

        let usesSimplified = WidgetLanguage.current == .simplifiedChinese
        return (usesSimplified ? simplifiedNames : traditionalNames)[operatorId]
            ?? operatorId
    }

    private static func color(for operatorId: String) -> Color {
        switch operatorId {
        case "KMB": .red
        case "LWB": Color(red: 0.95, green: 0.45, blue: 0.08)
        case "CTB": Color(red: 1, green: 0.82, blue: 0)
        case "NLB": Color(red: 0.35, green: 0.75, blue: 0.95)
        case "GMB": .green
        case "LRTFeeder": Color(red: 0.15, green: 0.32, blue: 0.62)
        case "PI": .teal
        case "DB": .purple
        default: .gray
        }
    }
}

struct TransitGoETAWidget: Widget {
    let kind = "TransitGoETAWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectFavoriteETAIntent.self,
            provider: TransitGoETAProvider()
        ) { entry in
            TransitGoETAWidgetView(entry: entry)
        }
        .configurationDisplayName("Favorite ETA")
        .description("View the latest arrivals for a HK Way favorite.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct HKWayWidgetBundle: WidgetBundle {
    var body: some Widget {
        TransitGoETAWidget()
        StopAlertLiveActivity()
    }
}
