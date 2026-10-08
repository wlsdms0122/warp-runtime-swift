//
//  Declared.swift
//  Warp
//
//  Created by JSilver on 9/21/26.
//

import Foundation

// What a declaration says of itself that another document reads: what it
// takes and answers, and who may name it. One entry of the space a link
// resolves spellings in.
struct Declared: Sendable {
    // MARK: - Property
    let signature: Signature
    let access: Access

    // What the build worked out of the declaration, where its row stands:
    // whether it answers without running, whether it touches nothing another
    // body could touch at once, what it may fail with, and what its body
    // answers where it wrote no `returns`. Nil for a declaration being
    // compiled now, whose row does not stand yet.
    let facts: (constness: Constness, isolation: Isolation, failing: Failing, answer: LoweredType?)?

    // MARK: - Initializer
    init(
        signature: Signature,
        access: Access,
        facts: (constness: Constness, isolation: Isolation, failing: Failing, answer: LoweredType?)? = nil
    ) {
        self.signature = signature
        self.access = access
        self.facts = facts
    }

    // MARK: - Public
    // MARK: - Private
}
