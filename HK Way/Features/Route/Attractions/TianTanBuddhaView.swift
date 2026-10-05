import SwiftUI

struct TianTanBuddhaView: View {
    private let accent = Color(red: 0.57, green: 0.38, blue: 0.16)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                card("Tian Tan Buddha", icon: "mountain.2.fill") {
                    Text("Plan your transport below. For attraction details, please visit the official websites.")
                        .font(.subheadline)
                }

                card("How to Get There", icon: "signpost.right.fill") {
                    NavigationLink {
                        BuddhaBusRoutesView()
                    } label: {
                        actionRow("Bus Routes to Ngong Ping", subtitle: "23 from Tung Chung · 2 from Mui Wo · 21 from Tai O", icon: "bus.fill")
                    }
                    .buttonStyle(.plain)
                    Text("The bus list uses the Ngong Ping terminus in the transport dataset. It does not plan the final approach to the attraction.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Divider()
                    Text("Via Tung Chung").font(.subheadline.bold())
                    Text("Take the MTR to Tung Chung, then take NLB bus 23 from Tung Chung Tat Tung Road Bus Terminus to Ngong Ping.")
                        .font(.subheadline)
                    NavigationLink {
                        MTRJourneyPlannerView(viaTungChung: true)
                    } label: {
                        actionRow("MTR Journey Planner", subtitle: "Choose your starting station · Destination: Tung Chung", icon: "tram.fill")
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        NgongPing360View()
                    } label: {
                        actionRow("Ngong Ping 360", subtitle: "Transport connections & official links", icon: "cablecar.fill")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    Text("Via Mui Wo or Tai O").font(.subheadline.bold())
                    Text("From Mui Wo Ferry Pier, take NLB bus 2 to Ngong Ping. From Tai O, take NLB bus 21 to Ngong Ping. Check the operator's timetable before travelling; connections are not guaranteed.")
                        .font(.subheadline)
                    externalLink("Sun Ferry — Official Information", url: "https://www.sunferry.com.hk/", icon: "ferry.fill")
                }

                card("Visitor Information", icon: "link") {
                    Text("Check the official websites for opening hours, admission, accessibility, contact details and service notices. HK Way does not reproduce those details here.")
                        .font(.footnote).foregroundStyle(.secondary)
                    externalLink("Po Lin Monastery — Visitor Information", url: "https://plm.org.hk/eng/visitors.php")
                    Divider()
                    externalLink("About Tian Tan Buddha", url: "https://plm.org.hk/eng/buddha.php")
                    Divider()
                    externalLink("Big Buddha — Ngong Ping 360 Guide", url: "https://www.np360.com.hk/en/things-to-do/nearby-attractions/big-buddha")
                    Divider()
                    externalLink("New Lantao Bus — Routes & Timetables", url: "https://www.nlb.com.hk/route")
                    Text("External links open third-party websites. HK Way is independent and is not affiliated with the attraction or transport operators.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .background(accent.opacity(0.10).ignoresSafeArea())
        .navigationTitle("Tian Tan Buddha")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card<Content: View>(_ title: LocalizedStringKey, icon: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .customInfoCardSurface(cornerRadius: 22)
    }

    private func actionRow(_ title: LocalizedStringKey, subtitle: LocalizedStringKey,
                           icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func externalLink(_ title: LocalizedStringKey, url: String, icon: String = "safari") -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(accent).frame(width: 28)
                Text(title).font(.subheadline)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right").font(.caption.bold()).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }
}
