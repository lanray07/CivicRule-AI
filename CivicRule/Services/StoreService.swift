import Foundation
import StoreKit
import Observation

@MainActor @Observable final class StoreService {
    var products: [Product] = []
    var entitledIDs: Set<String> = []
    var message = ""
    var busy = false
    // Empty until actual products, benefits and prices are approved in App Store Connect.
    let productIDs: [String]
    private var updates: Task<Void, Never>?
    init(productIDs: [String] = []) {
        self.productIDs = productIDs
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
    }
    deinit { updates?.cancel() }
    func load() async {
        do { products = try await Product.products(for: productIDs); await refreshEntitlements() }
        catch { message = error.localizedDescription }
    }
    func refreshEntitlements() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil, productIDs.contains(transaction.productID) { ids.insert(transaction.productID) }
        }
        entitledIDs = ids
    }
    func purchase(_ product: Product) async {
        busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)): await refreshEntitlements(); await transaction.finish(); message = "Purchase restored to your device."
            case .success(.unverified): message = "The purchase could not be verified. Access has not changed."
            case .pending: message = "Purchase awaiting approval."
            case .userCancelled: break
            @unknown default: message = "Please try again later."
            }
        } catch { message = error.localizedDescription }
    }
    func restore() async {
        do { try await AppStore.sync(); await refreshEntitlements(); message = entitledIDs.isEmpty ? "No active CivicRule purchases found." : "Purchases restored." }
        catch { message = error.localizedDescription }
    }
}

