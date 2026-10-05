import SwiftUI

struct MaWanView: View {
    @Environment(\.transitLanguage) private var language

    private var officialBusURL: URL {
        let path = language == .english ? "en" : language == .traditionalChinese ? "tc" : "sc"
        return URL(string: "https://www.td.gov.hk/\(path)/transport_in_hong_kong/public_transport/non_franchised/list_of_approved_rs_nt/index.html")!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ma Wan Transport")
                    .font(.title2.bold())

                sectionHeader("Ferry", icon: "ferry.fill", color: .cyan)
                CustomInfoCardView(title: "") {
                    VStack(spacing: 0) {
                        ForEach(FerryCatalogue.routes(in: .maWan)) { route in
                            NavigationLink {
                                FerryConnectionView(route: route, departure: .maWan)
                            } label: {
                                routeRow(code: "", destination: route.arrival(from: .maWan).location.title,
                                         icon: "ferry.fill", color: .cyan)
                            }
                            .buttonStyle(.plain)
                            if route.id != FerryCatalogue.routes(in: .maWan).last?.id { Divider() }
                        }
                    }
                }

                sectionHeader("Bus", icon: "bus.fill", color: .teal)
                CustomInfoCardView(title: "") {
                    VStack(spacing: 0) {
                        ForEach(Array(MaWanResidentBusCatalogue.routes.enumerated()), id: \.element.id) { index, route in
                            Link(destination: route.officialURL) {
                                routeRow(code: route.number, destination: route.destination, icon: "bus.fill", color: .teal)
                            }
                            .buttonStyle(.plain)
                            if index < MaWanResidentBusCatalogue.routes.count - 1 { Divider() }
                        }
                    }
                }

                Text("Resident-bus availability and passenger arrangements may vary. Check the official route document before travelling. First and last departures will be added later as a shared timetable feature.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Link("Official Ma Wan Bus Route List", destination: officialBusURL)
                    .foregroundStyle(.primary)
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .background(Color.teal.opacity(0.10).ignoresSafeArea())
        .navigationTitle("Ma Wan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        Label(LocalizedStringKey(title), systemImage: icon)
            .font(.headline)
            .foregroundStyle(color)
    }

    private func routeRow(code: String, destination: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                if !code.isEmpty { Text(code).font(.headline) }
                Text(LocalizedStringKey(destination)).foregroundStyle(.primary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}
