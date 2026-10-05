import Foundation
import Observation
import StoreKit

enum SupportTip: Int, CaseIterable, Identifiable {
    case eight = 8
    case eighteen = 18
    case thirtyEight = 38
    case eightyEight = 88

    var id: String { "com.kenwong.hkway.tip.v2.\(rawValue)" }
}

@MainActor
@Observable
final class PurchaseManager {
    private(set) var tipProducts: [String: Product] = [:]
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var message: String?

    // Tips never unlock functionality. Keep existing access-policy callers
    // compatible while all users receive unrestricted access.
    var accessTier: AppAccessTier { .full }

    private var hasStarted = false
    private var transactionUpdatesTask: Task<Void, Never>?

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        observeTransactionUpdates()
        await loadProducts()
    }

    func purchaseTip(_ tip: SupportTip) async {
        guard let product = tipProducts[tip.id], !isPurchasing else { return }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result,
                      transaction.productID == tip.id else {
                    message = String(localized: "The purchase could not be verified.")
                    return
                }
                await transaction.finish()
                message = String(localized: "Thank you for supporting HK Way.")
            case .pending:
                message = String(localized: "The purchase is pending approval.")
            case .userCancelled:
                break
            @unknown default:
                message = String(localized: "The purchase could not be completed.")
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func retryLoadingProduct() async {
        guard !isLoading else { return }
        message = nil
        await loadProducts()
    }

    private func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: SupportTip.allCases.map(\.id))
            tipProducts = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            message = error.localizedDescription
        }
    }

    private func observeTransactionUpdates() {
        transactionUpdatesTask = Task {
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result,
                   SupportTip.allCases.contains(where: { $0.id == transaction.productID }) {
                    await transaction.finish()
                }
            }
        }
    }
}
