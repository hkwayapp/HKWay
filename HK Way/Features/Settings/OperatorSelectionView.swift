import SwiftUI
import SwiftData

struct OperatorSelectionView: View {

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Query(sort: \OperatorEntity.id)
    private var operators: [OperatorEntity]

    @AppStorage(OperatorSelectionPreference.storageKey)
    private var selectedOperatorIdsValue = ""

    private var selectedOperatorIds: Set<String> {
        OperatorSelectionPreference.ids(
            from: selectedOperatorIdsValue
        )
    }

    private var selectableOperators: [OperatorEntity] {
        operators.filter {
            !$0.id.contains("+")
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    selectedOperatorIdsValue = ""
                } label: {
                    allOperatorsSelectionLabel
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    Color(
                        uiColor:
                            .secondarySystemGroupedBackground
                    )
                )
            }

            Section("Operators") {
                ForEach(selectableOperators) { operatorEntity in
                    Button {
                        toggle(operatorEntity.id)
                    } label: {
                        operatorSelectionLabel(
                            operatorEntity: operatorEntity,
                            isSelected: selectedOperatorIds
                                .contains(operatorEntity.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Operators")
        .tint(.primary)
    }

    private var allOperatorsSelectionLabel: some View {
        HStack {
            Text("All Operators")
                .foregroundStyle(.primary)

            Spacer()

            if selectedOperatorIds.isEmpty {
                Image(systemName: "checkmark")
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func operatorSelectionLabel(
        operatorEntity: OperatorEntity,
        isSelected: Bool
    ) -> some View {
        HStack {
            Text(
                operatorEntity.displayName(
                    for: transitLanguage
                )
            )
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func toggle(_ operatorId: String) {
        var selection = selectedOperatorIds

        if selection.contains(operatorId) {
            selection.remove(operatorId)
        } else {
            selection.insert(operatorId)
        }

        selectedOperatorIdsValue =
            OperatorSelectionPreference.value(
                from: selection
            )
    }
}

#Preview {
    NavigationStack {
        OperatorSelectionView()
    }
    .modelContainer(
        for: OperatorEntity.self,
        inMemory: true
    )
}
