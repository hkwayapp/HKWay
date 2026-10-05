import Foundation
import SwiftUI

struct TunnelTrafficView: View {
    private enum CameraSegment: String, CaseIterable, Identifiable {
        case tunnels
        case highways

        var id: Self { self }
    }

    enum HighwayRegion: String, CaseIterable, Identifiable {
        case all
        case hongKongIsland
        case kowloon
        case newTerritories

        var id: Self { self }

        func title(_ language: TransitLanguage) -> String {
            switch self {
            case .all: language.newsText("All", "全部", "全部")
            case .hongKongIsland: language.newsText("Hong Kong Island", "香港島", "香港岛")
            case .kowloon: language.newsText("Kowloon", "九龍", "九龙")
            case .newTerritories: language.newsText("New Territories", "新界", "新界")
            }
        }
    }

    @Environment(\.transitLanguage) private var language
    @State private var store = TunnelTrafficStore()
    @State private var segment: CameraSegment = .tunnels
    @State private var highwayRegion: HighwayRegion = .all
    @State private var selectedCamera: TrafficCamera?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Camera category", selection: $segment) {
                    Text(localized("Tunnels", "隧道", "隧道")).tag(CameraSegment.tunnels)
                    Text(localized("Highways", "公路", "公路")).tag(CameraSegment.highways)
                }
                .pickerStyle(.segmented)

                if segment == .tunnels {
                    tunnelContent
                } else {
                    highwayContent
                }

                Text(localized(
                    "Journey times and snapshots are provided by the Transport Department through DATA.GOV.HK and normally update every two minutes.",
                    "行車時間及交通影像由香港運輸署透過 DATA.GOV.HK 提供，一般每兩分鐘更新。",
                    "行车时间及交通影像由香港运输署通过 DATA.GOV.HK 提供，通常每两分钟更新。"
                ))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .navigationTitle(localized("Road Traffic", "道路交通", "道路交通"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .task { await store.refresh() }
        .fullScreenCover(item: $selectedCamera) { camera in
            TrafficCameraFullscreenView(camera: camera, language: language)
        }
    }

    private var tunnelContent: some View {
        Group {
            Text(localized("Current Journey Times", "現時行車時間", "当前行车时间"))
                .font(.headline)

            HStack(alignment: .top, spacing: 8) {
                ForEach(TunnelTrafficTunnel.allCases) { tunnel in
                    CustomInfoCardView(title: tunnel.shortName(language)) {
                        VStack(spacing: 3) {
                            Text(store.timeText(for: tunnel, language: language))
                                .font(.title3.bold())
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Circle()
                                .fill(store.colour(for: tunnel))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
            }

            Text(localized("Tunnel Snapshots", "隧道實時影像", "隧道实时影像"))
                .font(.headline)
            cameraList(TrafficCamera.tunnels)
        }
    }

    private var highwayContent: some View {
        Group {
            Text(localized("Highway Snapshots", "公路實時影像", "公路实时影像"))
                .font(.headline)
            Text(localized(
                "Major-road cameras from the Transport Department.",
                "運輸署提供的主要道路交通影像。",
                "运输署提供的主要道路交通影像。"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HighwayRegion.allCases) { region in
                        Button { highwayRegion = region } label: {
                            Text(region.title(language))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(highwayRegion == region ? .white : .primary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(highwayRegion == region ? Color.accentColor : Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            let cameras = TrafficCamera.highways.filter {
                highwayRegion == .all || $0.region == highwayRegion
            }
            cameraList(cameras)
        }
    }

    private func cameraList(_ cameras: [TrafficCamera]) -> some View {
        VStack(spacing: 12) {
            ForEach(cameras) { camera in
                Button { selectedCamera = camera } label: {
                    CustomInfoCardView(title: "") {
                        HStack(spacing: 14) {
                            cameraImage(camera, size: CGSize(width: 128, height: 86))
                            VStack(alignment: .leading, spacing: 7) {
                                Text(camera.name(language))
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let tunnel = camera.tunnel {
                                    Text(store.timeText(for: tunnel, language: language))
                                        .font(.title3.bold())
                                        .foregroundStyle(store.colour(for: tunnel))
                                }
                                Text(localized(
                                    "Tap to enlarge · updates about every 2 minutes",
                                    "點按放大 · 約每兩分鐘更新",
                                    "点按放大 · 约每两分钟更新"
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint(localized("Opens the traffic camera full screen.", "以全螢幕開啟交通影像。", "以全屏打开交通影像。"))
            }
        }
    }

    private func cameraImage(_ camera: TrafficCamera, size: CGSize) -> some View {
        AsyncImage(url: camera.snapshotURL) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .failure: snapshotPlaceholder
            default: ProgressView()
            }
        }
        .frame(width: size.width, height: size.height)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .clipped()
    }

    private var snapshotPlaceholder: some View {
        Image(systemName: "video.slash")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func localized(
        _ english: String,
        _ traditional: String,
        _ simplified: String
    ) -> String {
        language.newsText(english, traditional, simplified)
    }
}

private struct TrafficCamera: Identifiable {
    let id: String
    let english: String
    let traditional: String
    let simplified: String
    let tunnel: TunnelTrafficTunnel?
    let region: TunnelTrafficView.HighwayRegion?

    var snapshotURL: URL? { URL(string: "https://tdcctv.data.one.gov.hk/\(id).JPG") }

    func name(_ language: TransitLanguage) -> String {
        language.newsText(english, traditional, simplified)
    }

    static let tunnels: [TrafficCamera] = [
        .init(id: "K107F", english: "Cross-Harbour Tunnel", traditional: "海底隧道（紅隧）", simplified: "海底隧道（红隧）", tunnel: .crossHarbour, region: nil),
        .init(id: "H802F", english: "Eastern Harbour Crossing", traditional: "東區海底隧道", simplified: "东区海底隧道", tunnel: .easternHarbour, region: nil),
        .init(id: "K914F", english: "Western Harbour Crossing", traditional: "西區海底隧道", simplified: "西区海底隧道", tunnel: .westernHarbour, region: nil)
    ]

    static let highways: [TrafficCamera] = [
        .init(id: "H210F", english: "Aberdeen Tunnel · Wan Chai Side", traditional: "香港仔隧道（灣仔方向）", simplified: "香港仔隧道（湾仔方向）", tunnel: nil, region: .hongKongIsland),
        .init(id: "H215F", english: "Gloucester Road near Wan Chai Interchange", traditional: "告士打道近灣仔交匯處", simplified: "告士打道近湾仔交汇处", tunnel: nil, region: .hongKongIsland),
        .init(id: "H801F", english: "Island Eastern Corridor near Ka Wah Centre", traditional: "東區走廊近嘉華中心", simplified: "东区走廊近嘉华中心", tunnel: nil, region: .hongKongIsland),
        .init(id: "K814F", english: "Kwun Tong Bypass near Kai Cheung Road", traditional: "觀塘繞道近啟祥道", simplified: "观塘绕道近启祥道", tunnel: nil, region: .kowloon),
        .init(id: "AID03108", english: "West Kowloon Highway near Olympic MTR Station · Northbound", traditional: "西九龍公路近奧運站 · 北行", simplified: "西九龙公路近奥运站 · 北行", tunnel: nil, region: .kowloon),
        .init(id: "AID02113", english: "Kwun Tong Bypass near MegaBox · Northbound", traditional: "觀塘繞道近 MegaBox · 北行", simplified: "观塘绕道近 MegaBox · 北行", tunnel: nil, region: .kowloon),
        .init(id: "AID07104", english: "Tseung Kwan O Tunnel Road near tunnel portal · Westbound", traditional: "將軍澳隧道公路近隧道入口 · 西行", simplified: "将军澳隧道公路近隧道入口 · 西行", tunnel: nil, region: .kowloon),
        .init(id: "TH110F", english: "Tolo Highway near Hong Kong Science Park", traditional: "吐露港公路近香港科學園", simplified: "吐露港公路近香港科学园", tunnel: nil, region: .newTerritories),
        .init(id: "TC604F", english: "Ting Kau Bridge", traditional: "汀九橋", simplified: "汀九桥", tunnel: nil, region: .newTerritories),
        .init(id: "TR101F", english: "Tuen Mun Road · Chai Wan Kok", traditional: "屯門公路－柴灣角", simplified: "屯门公路－柴湾角", tunnel: nil, region: .newTerritories),
        .init(id: "AID09122", english: "Tolo Highway near Sha Tin Sewage Treatment Works · Northbound", traditional: "吐露港公路近沙田污水處理廠 · 北行", simplified: "吐露港公路近沙田污水处理厂 · 北行", tunnel: nil, region: .newTerritories),
        .init(id: "AID02119", english: "Tates Cairn Highway near Hong Kong School of Motoring · Northbound", traditional: "大老山公路近香港駕駛學院 · 北行", simplified: "大老山公路近香港驾驶学院 · 北行", tunnel: nil, region: .newTerritories),
        .init(id: "AID09154", english: "Fanling Highway near So Kwun Po Road · Eastbound", traditional: "粉嶺公路近掃管埔路 · 東行", simplified: "粉岭公路近扫管埔路 · 东行", tunnel: nil, region: .newTerritories),
        .init(id: "AID09114", english: "Shing Mun Tunnel Road near Hong Kong Heritage Museum · Eastbound", traditional: "城門隧道公路近香港文化博物館 · 東行", simplified: "城门隧道公路近香港文化博物馆 · 东行", tunnel: nil, region: .newTerritories)
    ]
}

private struct TrafficCameraFullscreenView: View {
    let camera: TrafficCamera
    let language: TransitLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AsyncImage(url: camera.snapshotURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: Image(systemName: "video.slash").font(.largeTitle).foregroundStyle(.white)
                    default: ProgressView().tint(.white)
                    }
                }
                .padding()
            }
            .navigationTitle(camera.name(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.newsText("Done", "完成", "完成")) { dismiss() }
                }
            }
        }
    }
}

enum TunnelTrafficTunnel: String, CaseIterable, Identifiable {
    case crossHarbour = "CH"
    case easternHarbour = "EH"
    case westernHarbour = "WH"

    var id: String { rawValue }

    func shortName(_ language: TransitLanguage) -> String {
        switch self {
        case .crossHarbour: language.newsText("Cross-Harbour", "紅隧", "红隧")
        case .easternHarbour: language.newsText("Eastern", "東隧", "东隧")
        case .westernHarbour: language.newsText("Western", "西隧", "西隧")
        }
    }

    func name(_ language: TransitLanguage) -> String {
        switch self {
        case .crossHarbour:
            language.newsText("Cross-Harbour Tunnel", "海底隧道（紅隧）", "海底隧道（红隧）")
        case .easternHarbour:
            language.newsText("Eastern Harbour Crossing", "東區海底隧道", "东区海底隧道")
        case .westernHarbour:
            language.newsText("Western Harbour Crossing", "西區海底隧道", "西区海底隧道")
        }
    }

    var snapshotURL: URL? {
        let camera = switch self {
        case .crossHarbour: "K107F"
        case .easternHarbour: "H802F"
        case .westernHarbour: "K914F"
        }
        return URL(string: "https://tdcctv.data.one.gov.hk/\(camera).JPG")
    }
}

@MainActor
@Observable
final class TunnelTrafficStore {
    private var records: [String: TunnelJourneyTime] = [:]

    func refresh() async {
        guard let url = URL(string: "https://resource.data.one.gov.hk/td/jss/Journeytimev2.xml") else {
            return
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: request)
            let parsed = TunnelJourneyTimeParser.parse(data)

            var preferred: [String: TunnelJourneyTime] = [:]
            for destination in TunnelTrafficTunnel.allCases {
                let matches = parsed.filter {
                    $0.destinationID == destination.rawValue && $0.minutes != nil
                }
                preferred[destination.rawValue] =
                    matches.first(where: { $0.locationID == "H2" }) ?? matches.first
            }
            records = preferred
        } catch {
            // Preserve the most recent successful values during a temporary outage.
        }
    }

    func timeText(for tunnel: TunnelTrafficTunnel, language: TransitLanguage) -> String {
        guard let minutes = records[tunnel.rawValue]?.minutes else {
            return language.newsText("—", "—", "—")
        }
        return language.newsText(
            "\(minutes) min",
            "\(minutes) 分鐘",
            "\(minutes) 分钟"
        )
    }

    func colour(for tunnel: TunnelTrafficTunnel) -> Color {
        switch records[tunnel.rawValue]?.colourID {
        case 1: .red
        case 2: .orange
        case 3: .green
        default: .secondary
        }
    }

    var hasJourneyOverTenMinutes: Bool {
        TunnelTrafficTunnel.allCases.contains { tunnel in
            guard let minutes = records[tunnel.rawValue]?.minutes else {
                return false
            }
            return minutes > 10
        }
    }
}

private struct TunnelJourneyTime {
    let locationID: String
    let destinationID: String
    let minutes: Int?
    let colourID: Int?
}

private final class TunnelJourneyTimeParser: NSObject, XMLParserDelegate {
    private var records: [TunnelJourneyTime] = []
    private var values: [String: String] = [:]
    private var currentElement = ""
    private var text = ""

    static func parse(_ data: Data) -> [TunnelJourneyTime] {
        let delegate = TunnelJourneyTimeParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.records
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        text = ""
        if elementName == "jtis_journey_time" {
            values = [:]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            values[elementName] = value
        }

        if elementName == "jtis_journey_time",
           let locationID = values["LOCATION_ID"],
           let destinationID = values["DESTINATION_ID"] {
            records.append(
                TunnelJourneyTime(
                    locationID: locationID,
                    destinationID: destinationID,
                    minutes: Int(values["JOURNEY_DATA"] ?? ""),
                    colourID: Int(values["COLOUR_ID"] ?? "")
                )
            )
        }
        currentElement = ""
        text = ""
    }
}
