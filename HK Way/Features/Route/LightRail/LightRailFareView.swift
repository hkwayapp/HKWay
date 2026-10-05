import SwiftUI

struct LightRailFareView: View {
    let boardingStop: LightRailStop
    let destinations: [LightRailStop]
    @Environment(\.transitLanguage) private var language
    @State private var destinationID: Int = -1
    @State private var fares: [String: LightRailAdultFare] = [:]
    @State private var loaded = false

    private var selectedDestination: LightRailStop? {
        destinations.first { $0.stationID == destinationID } ?? destinations.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adult Fares").font(.headline)
            if let destination = selectedDestination {
                HStack(spacing: 8) {
                    Text("To").font(.headline)
                Picker("Fare Destination", selection: Binding(
                    get: { selectedDestination?.stationID ?? -1 },
                    set: { destinationID = $0 }
                )) {
                    ForEach(destinations, id: \.stationID) { stop in
                        Text(name(stop)).tag(stop.stationID)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !loaded {
                    ProgressView("Loading Fares…")
                } else if let fare = fares[LightRailFares.key(from: boardingStop.stationID, to: destination.stationID)] {
                    HStack(spacing: 12) {
                        CustomInfoCardView(title: "Adult Octopus") {
                            Text(price(fare.octopus)).font(.title2.bold()).minimumScaleFactor(0.75).lineLimit(1)
                        }
                        CustomInfoCardView(title: "Adult Single Journey") {
                            Text(price(fare.singleJourney)).font(.title2.bold()).minimumScaleFactor(0.75).lineLimit(1)
                        }
                    }
                } else {
                    Text("Fare unavailable for this journey.").foregroundStyle(.secondary)
                }
            } else {
                Text("This is the final stop. Choose the opposite direction to check a fare.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .task {
            fares = (try? LightRailFares.load()) ?? [:]
            loaded = true
        }
    }

    private func price(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_HK")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "HK$" + (formatter.string(from: NSDecimalNumber(decimal: value)) ?? "—")
    }

    private func name(_ stop: LightRailStop) -> String {
        switch language {
        case .english: stop.english
        case .traditionalChinese: stop.traditional
        case .simplifiedChinese: stop.simplified
        }
    }
}
