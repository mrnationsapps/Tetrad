//
//  Products.swift
//  Sqword
//
//  Created by kevin nations on 10/19/25.
//
// Products.swift

import StoreKit

enum CoinProduct: String, CaseIterable, Identifiable {
    case coins50  = "coins_50"
    case coins200 = "coins_200"

    var id: String { rawValue }

    /// Map verified purchases → coin credit
    var coinAmount: Int {
        switch self {
        case .coins50:  return 50
        case .coins200: return 200
        }
    }
}

