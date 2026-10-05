import SwiftUI

struct PengChauTimetableView: View {
    let departure: FerryPier
    @State private var day: FerryServiceDay = .weekday
    @State private var timetable: PengChauTimetable?
    @State private var failed = false

    var body: some View {
        CustomInfoCardView(title: "") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Scheduled Departures").font(.headline)
                Text("Timetable only — not live ETA")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text(LocalizedStringKey(departure == .central6West ? "Central → Peng Chau" : "Peng Chau → Central"))
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
                    Text("Select the service day manually, including public holidays. Times use the Hong Kong time zone and a 24-hour clock.")
                        .font(.footnote).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                        ForEach(timetable.departures(fromCentral: departure == .central6West, day: day)) { sailing in
                            VStack(spacing: 4) {
                                Text(verbatim: sailing.clock).font(.title3.weight(.medium)).monospacedDigit()
                                if sailing.nextDay {
                                    Text("Next calendar day").font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .padding(6)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Text("The 00:30 departure belongs to the following calendar day of the selected service day. Hei Ling Chau services are not included.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    ProgressView("Loading timetable…").frame(maxWidth: .infinity)
                }
                Divider()
                Text("Timetable snapshot retrieved: 2026-08-31. Schedules may change; check official notices before travelling.")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("Timetable Open Data Source", destination: URL(string: "https://data.gov.hk/en-data/dataset/hk-td-wcms_8-ferry-services-tt-ft/resource/8063da96-a761-4344-90f7-03851116565c")!)
                    .font(.footnote).foregroundStyle(.primary)
            }
            .padding(6).frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.primary)
        .task {
            guard timetable == nil, !failed else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            do { timetable = try PengChauTimetable.load() }
            catch { failed = true }
        }
    }
}
