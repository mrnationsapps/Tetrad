//
//  IAPManager.swift
//  Sqword
//
//  Created by kevin nations on 10/19/25.
//

// IAPManager.swift

import Foundation
import StoreKit

@MainActor
final class IAPManager: ObservableObject {
    @Published private(set) var products: [CoinProduct: Product] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var purchasing: CoinProduct? = nil
    @Published var lastError: String? = nil

    private var updatesTask: Task<Void, Never>?

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let ids = Set(CoinProduct.allCases.map(\.rawValue))
            let storeProducts = try await Product.products(for: ids)
            var map: [CoinProduct: Product] = [:]
            for p in storeProducts {
                if let key = CoinProduct(rawValue: p.id) {
                    map[key] = p
                }
            }
            self.products = map
        } catch {
            lastError = "Failed to load products: \(error.localizedDescription)"
        }
    }

    /// Purchase a coin pack, then call `credit` on success.
    func purchase(_ which: CoinProduct, credit: @escaping (Int) -> Void) async {
        guard let product = products[which] else {
            lastError = "Product not available."
            return
        }
        purchasing = which
        defer { purchasing = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try await self.verify(verification)
                // Consumable: credit immediately, then finish
                credit(which.coinAmount)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                // Waiting for SCA/approval — will be delivered via updates listener
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    /// Start listening for delayed/restore transactions (consumables rarely restore,
    /// but pending SCA can arrive here).
    func startTransactionListener(credit: @escaping (_ productID: String) -> Void) {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update, credit: credit)
            }
        }
    }

    func stopTransactionListener() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    // MARK: - Helpers
    private func verify(_ result: VerificationResult<Transaction>) async throws -> Transaction {
        switch result {
        case .unverified(_, let error):
            throw error ?? IAPError.unverified
        case .verified(let tx):
            return tx
        }
    }

    private func handle(_ result: VerificationResult<Transaction>,
                        credit: @escaping (_ productID: String) -> Void) async {
        do {
            let tx = try await verify(result)
            // Credit only our known consumables
            credit(tx.productID)
            await tx.finish()
        } catch {
            await MainActor.run { self.lastError = "Transaction unverified." }
        }
    }

    enum IAPError: Error { case unverified }
}

