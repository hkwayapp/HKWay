//
//  CustomCurrentStopETAView.swift
//  HK Way
//

import SwiftUI

struct CustomCurrentStopETAView: View {
    let directionName: String?
    let stopName: String?
    let stopCode: String?
    let showsStopName: Bool
    let etaResult: RouteETAResult?
    let isLoading: Bool
    let isUnavailable: Bool
    let didFail: Bool

    init(
        directionName: String? = nil,
        stopName: String?,
        stopCode: String? = nil,
        showsStopName: Bool = true,
        etaResult: RouteETAResult?,
        isLoading: Bool,
        isUnavailable: Bool,
        didFail: Bool
    ) {
        self.directionName = directionName
        self.stopName = stopName
        self.stopCode = stopCode
        self.showsStopName = showsStopName
        self.etaResult = etaResult
        self.isLoading = isLoading
        self.isUnavailable = isUnavailable
        self.didFail = didFail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let stopName {
                if showsStopName {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(stopName)
                            .font(.headline)

                        if let stopCode {
                            Text(verbatim: "(\(stopCode))")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let directionName {
                    Text("Towards \(directionName)")
                        .bold()
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                etaContent
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Finding nearest stop...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    @ViewBuilder
    private var etaContent: some View {
        if isLoading {
            ProgressView("Loading arrivals...")
        } else if isUnavailable {
            statusText("ETA unavailable")
        } else if didFail {
            statusText("Unable to load ETA")
        } else if let etaResult {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let allArrivals = etaResult.etaRecords
                    .compactMap(\.estimatedArrival)
                    .sorted()

                let upcomingArrivals = allArrivals
                    .filter { $0 > context.date }
                    .prefix(3)

                let mostRecentDeparture = allArrivals
                    .last { $0 <= context.date }

                let shouldKeepDeparture =
                    !upcomingArrivals.isEmpty
                    || mostRecentDeparture.map {
                        context.date.timeIntervalSince($0) < 60
                    } == true

                let visibleArrivals = Array(
                    (
                        shouldKeepDeparture
                        ? [mostRecentDeparture].compactMap { $0 }
                        : []
                    )
                    + Array(upcomingArrivals)
                )

                if visibleArrivals.isEmpty {
                    statusText("No upcoming arrivals")
                } else {
                    VStack(spacing: 8) {
                        ForEach(
                            Array(visibleArrivals.enumerated()),
                            id: \.offset
                        ) { _, arrival in
                            HStack {
                                Text(
                                    arrival,
                                    format: .dateTime
                                        .hour()
                                        .minute()
                                )
                                .fontWeight(.medium)
                                .monospacedDigit()

                                Spacer()

                                if arrival <= context.date {
                                    Text("About to depart")
                                        .fontWeight(.semibold)
                                } else {
                                    Text(arrival, style: .relative)
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
        } else {
            statusText("Waiting for ETA...")
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(LocalizedStringKey(text))
            .foregroundStyle(.secondary)
    }

}
