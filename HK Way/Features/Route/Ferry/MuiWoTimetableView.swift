import SwiftUI

struct MuiWoTimetableView: View {
    let departure: FerryPier
    let type: CheungChauFerryType
    @State private var day: FerryServiceDay = .weekday
    @State private var timetable: MuiWoTimetable?
    @State private var failed = false

    var body: some View {
        CustomInfoCardView(title: "") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Scheduled Departures").font(.headline)
                Text("Timetable only — not live ETA")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text(LocalizedStringKey(departure == .central6East ? "Central → Mui Wo" : "Mui Wo → Central"))
                    .font(.headline)
                if failed {
                    Text("Unable to load the timetable. Please use the official timetable link below.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else if let timetable {
                    Picker("Service Day", selection: $day) {
                        ForEach(FerryServiceDay.allCases) { option in
                            Text(LocalizedStringKey(option.rawValue)).tag(option)
                        }
                    }
                    .pickerStyle(.menu).tint(.primary)
                    Text(LocalizedStringKey(type.rawValue))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(type == .fast ? Color.orange : Color.teal)
                    Text("Select the service day manually, including public holidays. Times use the Hong Kong time zone and a 24-hour clock.")
                        .font(.footnote).foregroundStyle(.secondary)
                    let departures = timetable.departures(fromCentral: departure == .central6East,
                                                           day: day, type: type)
                    if departures.isEmpty {
                        Text("No published departures for this service type and day.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                            ForEach(departures) { sailing in
                                VStack(spacing: 4) {
                                    Text(verbatim: sailing.clock).font(.title3.weight(.medium)).monospacedDigit()
                                    if sailing.nextDay { Text("Next calendar day").font(.caption) }
                                    if sailing.operatingNote == .viaPengChau {
                                        Text("Via Peng Chau · alighting only").font(.caption)
                                    }
                                }
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .padding(6)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                } else {
                    ProgressView("Loading timetable…").frame(maxWidth: .infinity)
                }
                Divider()
                Text("Timetable snapshot retrieved: 2026-09-01. Schedules may change; check official notices before travelling.")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("Timetable Open Data Source", destination: URL(string: "https://data.gov.hk/en-data/dataset/hk-td-wcms_8-ferry-services-tt-ft/resource/5c11c040-ab67-4a61-a304-fa176d232037")!)
                    .font(.footnote).foregroundStyle(.primary)
            }
            .padding(6).frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.primary)
        .task {
            guard timetable == nil, !failed else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            do { timetable = try MuiWoTimetable.load() }
            catch { failed = true }
        }
    }
}
