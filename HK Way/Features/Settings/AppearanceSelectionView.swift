import SwiftUI

struct AppearanceSelectionView: View {
    @Environment(\.dismiss)
    private var dismiss

    @AppStorage(AppAppearance.storageKey)
    private var selectedAppearance = AppAppearance.system.rawValue

    var body: some View {
        Form {
            Section(
                footer: Text(
                    "Choose how HK Way appears on this device."
                )
            ) {
                ForEach(AppAppearance.allCases) { appearance in
                    Button {
                        selectedAppearance = appearance.rawValue
                        dismiss()
                    } label: {
                        HStack {
                            Text(appearance.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedAppearance == appearance.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.primary)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.primary)
    }
}

#Preview {
    NavigationStack {
        AppearanceSelectionView()
    }
}
