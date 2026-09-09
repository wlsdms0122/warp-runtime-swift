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
struct Claim {
    // MARK: - Property
    let type: Name
    let contract: Name

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
