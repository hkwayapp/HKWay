import StoreKit
import SwiftUI

struct SupportView: View {
    @Environment(PurchaseManager.self) private var purchaseManager

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Support HK Way", systemImage: "heart.fill")
                        .font(.title3.bold())
                    Text("HK Way is free to use. Every feature is available without a purchase. If you find it useful, you can leave an optional tip.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                ForEach(SupportTip.allCases) { tip in
                    Button {
                        Task { await purchaseManager.purchaseTip(tip) }
                    } label: {
                        HStack {
                            Text("Tip HK Way")
                            Spacer()
                            if let product = purchaseManager.tipProducts[tip.id] {
                                Text(product.displayPrice)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("HK$\(tip.rawValue)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(purchaseManager.tipProducts[tip.id] == nil || purchaseManager.isPurchasing)
                }
            } header: {
                Text("Choose a tip")
            } footer: {
                Text("Tips are optional, do not unlock features, and can be given more than once. The App Store confirms the final local price before payment.")
            }

            if purchaseManager.isLoading {
                HStack {
                    ProgressView()
                    Text("Loading App Store products…")
                        .foregroundStyle(.secondary)
                }
            } else if purchaseManager.tipProducts.isEmpty {
                Section {
                    Text("Tips are not available from the App Store right now.")
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task { await purchaseManager.retryLoadingProduct() }
                    }
                }
            }

            if let message = purchaseManager.message {
                Section { Text(message) }
            }
        }
        .navigationTitle("Support HK Way")
        .tint(.primary)
    }
}

#Preview {
    NavigationStack {
        SupportView()
    }
    .environment(PurchaseManager())
}
