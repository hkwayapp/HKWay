import SwiftUI

private let crossBoundaryAccent = Color.indigo

struct CrossBoundaryView: View {
    @Environment(\.transitLanguage) private var language

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(ui("Cross-Boundary Coach", "跨境巴士", "跨境巴士"), systemImage: "bus.doubledecker.fill").font(.title2.bold())
                    Text(ui(
                        "Coach times, fares, boarding arrangements and immigration requirements can change. Confirm them on the official page before travelling.",
                        "班次、車費、上車安排及出入境要求可能更改，出發前請在官方頁面確認。",
                        "班次、车费、上车安排及出入境要求可能更改，出发前请在官方页面确认。"
                    ))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Label(ui("Official information only — no live ETA", "只提供官方資訊，沒有實時到站時間", "只提供官方资讯，没有实时到站时间"), systemImage: "clock.badge.questionmark")
                        .font(.footnote.weight(.semibold)).foregroundStyle(crossBoundaryAccent)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .customInfoCardSurface(cornerRadius: 22)

                sectionTitle(ui("Short-haul Services to Huanggang Port", "往返皇崗口岸的短途服務", "往返皇岗口岸的短途服务"))
                ForEach(CrossBoundaryCoachService.huanggang) { service in coachCard(service) }

                sectionTitle(ui("Long-haul and Macao Services", "長途及澳門服務", "长途及澳门服务"))
                gateway(ui("Trans-Island Chinalink", "環島中港通", "环岛中港通"), ui("Hong Kong ↔ Guangdong destinations", "香港 ↔ 廣東省各目的地", "香港 ↔ 广东省各目的地"), "https://www.chinalink.hk/faq.php?lang=en")
                gateway(ui("ONEBUS Hong Kong–Macao", "港澳一號", "港澳一号"), ui("Urban Hong Kong ↔ Macao via HZMB", "香港市區 ↔ 澳門（經港珠澳大橋）", "香港市区 ↔ 澳门（经港珠澳大桥）"), "https://www.onebus.hk/en/home")

                sectionTitle(ui("Official Directories", "官方名錄", "官方名录"))
                gateway(ui("Licensed Coach Operators by Control Point", "按管制站劃分的持牌巴士營辦商", "按管制站划分的持牌巴士营办商"), ui("Transport Department operator and enquiry directory", "運輸署營辦商及查詢名錄", "运输署营办商及查询名录"), "https://www.td.gov.hk/en/transport_in_hong_kong/land_based_cross_boundary_transport/enquiries/index.html")
                gateway(ui("HZMB Cross-Boundary Transport", "港珠澳大橋跨境交通", "港珠澳大桥跨境交通"), ui("Official coach, shuttle-bus and port information", "官方跨境巴士、穿梭巴士及口岸資訊", "官方跨境巴士、穿梭巴士及口岸资讯"), "https://www.hzmb.gov.hk/en/cross-boundary.html")

                Text(ui(
                    "HK Way does not sell tickets and is not affiliated with any operator. Services may require advance booking and valid travel documents.",
                    "HK Way 不售賣車票，亦不隸屬任何營辦商。服務可能需要預先訂票及有效旅遊證件。",
                    "HK Way 不售卖车票，也不隶属任何营办商。服务可能需要预先订票及有效旅游证件。"
                ))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(crossBoundaryAccent.opacity(0.09).ignoresSafeArea())
        .navigationTitle(ui("Cross-Boundary Coach", "跨境巴士", "跨境巴士"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.headline).foregroundStyle(.secondary).padding(.top, 4)
    }

    private func coachCard(_ service: CrossBoundaryCoachService) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(service.area(for: language)).font(.headline)
            Label(service.boardingPoint(for: language), systemImage: "mappin.and.ellipse")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(service.operatorName(for: language)).font(.caption).foregroundStyle(.secondary)
            Link(destination: service.officialURL) {
                Label(ui("Official Stops, Times and Fares", "官方車站、班次及車費", "官方车站、班次及车费"), systemImage: "arrow.up.right.square")
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .customInfoCardSurface(cornerRadius: 22)
    }

    private func gateway(_ title: String, _ detail: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.up.right.square").font(.title3).foregroundStyle(crossBoundaryAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary).padding(16).customInfoCardSurface(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }

    private func ui(_ english: String, _ traditional: String, _ simplified: String) -> String {
        switch language {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese: simplified
        }
    }
}

#Preview { NavigationStack { CrossBoundaryView() } }
