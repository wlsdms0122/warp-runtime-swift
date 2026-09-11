//
//  Claim.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// A document saying that one type answers one contract.
//
// It declares no name. What it says is about two names declared elsewhere,
// which is why it is gathered beside the three spaces rather than in one of
// them, and why what it holds is the pair itself.
struct Claim: Hashable, Comparable, Sendable {
    // MARK: - Property
    let type: Name
    let contract: Name

    // MARK: - Internal
    // Ordered so a set of them reads back the same way every time. The type
    // first, since that is the key an author wrote the claim under.
    static func < (lhs: Claim, rhs: Claim) -> Bool {
        (lhs.type, lhs.contract) < (rhs.type, rhs.contract)
    }

    // MARK: - Public
    // MARK: - Private
}
