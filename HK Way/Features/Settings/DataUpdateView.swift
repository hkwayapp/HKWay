import SwiftUI
import SwiftData

struct DataUpdateView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Query(sort: \OperatorEntity.id)
    private var operators: [OperatorEntity]

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    @State
    private var isUpdating = false

    @State
    private var updateState: UpdateState = .idle

    private let updateStore = ManualDatasetUpdateStore()

    private var sortedOperators: [OperatorEntity] {
        operators.sorted {
            $0.id.localizedStandardCompare($1.id) == .orderedAscending
        }
        .filter {
            $0.id != "KMB+CTB" &&
                $0.id != "LWB+CTB" &&
                $0.id != "PTRAM"
        }
    }

    private var updateFailedText: String {
        switch transitLanguage {
        case .english:
            "Unable to update the dataset. Please try again."
        case .traditionalChinese:
            "未能更新資料集，請再試一次。"
        case .simplifiedChinese:
            "无法更新数据集，请重试。"
        }
    }

    var body: some View {
        List {
            Section("Operators") {
                ForEach(sortedOperators) { operatorEntity in
                    HStack {
                        Text(
                            transitLanguage == .english
                                ? CustomBadgeView.displayText(
                                    for: operatorEntity.id
                                )
                                : operatorEntity.displayName(
                                    for: transitLanguage
                                )
                        )

                        Spacer()

                        Text(
                            "\(routeCount(for: operatorEntity)) routes"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                LabeledContent("Data Version") {
                    Text(
                        DatasetVersionStore()
                            .installedVersion
                        ?? "Not available"
                    )
                    .foregroundStyle(.secondary)
                }

                LabeledContent("Last Updated") {
                    if let lastUpdatedAt = updateStore.lastUpdatedAt {
                        Text(
                            lastUpdatedAt,
                            format: .dateTime
                                .year()
                                .month()
                                .day()
                                .hour()
                                .minute()
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        Text("Not available")
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    startManualUpdate()
                } label: {
                    HStack {
                        Text("Manual Update")
                            .foregroundStyle(.primary)

                        Spacer()

                        if isUpdating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(
                                systemName: "arrow.clockwise"
                            )
                        }
                    }
                }
                .disabled(
                    isUpdating ||
                    updateStore.remainingUpdatesToday == 0
                )

                if case .failed = updateState {
                    Text(updateFailedText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Dataset")
            } footer: {
                Group {
                    if updateStore.remainingUpdatesToday == 0 {
                        Text("Daily update limit reached")
                    } else if updateStore.remainingUpdatesToday == 1 {
                        Text("1 update remaining today")
                    } else {
                        Text(
                            "\(updateStore.remainingUpdatesToday) updates remaining today"
                        )
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
                .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("Data Update")
        .tint(.primary)
    }

    private func routeCount(
        for operatorEntity: OperatorEntity
    ) -> Int {
        switch operatorEntity.id {
        case "FERRY":
            return FerryCatalogue.routes.count
        case "TRAM":
            return (try? TramDatasetService.loadOffline().routes.count) ?? 0
        default:
            break
        }

        return routes.count { route in
            route.operators.contains {
                $0.id.split(separator: "+")
                    .map(String.init)
                    .contains(operatorEntity.id)
            }
        }
    }

    @MainActor
    private func startManualUpdate() {
        guard updateStore.beginManualUpdate() else {
            return
        }

        isUpdating = true
        updateState = .idle

        Task {
            defer {
                isUpdating = false
            }

            do {
                try await DatasetBootstrapper().bootstrap(
                    modelContext: modelContext
                )

                updateStore.recordSuccessfulUpdate()
                updateState = .updated
            } catch {
                updateState = .failed
            }
        }
    }
}

private enum UpdateState {
    case idle
    case updated
    case failed
}

#Preview {
    DataUpdateView()
        .modelContainer(
            for: [OperatorEntity.self, RouteEntity.self],
            inMemory: true
        )
}
