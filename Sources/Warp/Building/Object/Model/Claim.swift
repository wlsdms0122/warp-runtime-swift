//
//  Claim.swift
//  Warp
//
//  Created by JSilver on 9/10/26.
//

import Foundation

// A document saying that a type answers one contract, under the head it wrote
// it under: every value of the type where the head is bare, and the values the
// head takes otherwise.
//
// It declares no name. What it says is about a type, declared elsewhere or
// named by the language, and a contract declared elsewhere, which is why it is
// gathered beside the three tables rather than in one of them, and why what it
// holds is the pair itself.
struct Claim: Hashable, Comparable, Sendable {
    // MARK: - Property
    let head: Head
    let contract: Name

    var type: Name { head.type }

    // MARK: - Initializer
    // MARK: - Public
    // Ordered so a set of them reads back the same way every time. The head
    // first, since that is the key an author wrote it under.
    static func < (lhs: Claim, rhs: Claim) -> Bool {
        (lhs.head, lhs.contract) < (rhs.head, rhs.contract)
    }

    // MARK: - Private
}
