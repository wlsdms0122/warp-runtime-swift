//
//  AnswerProof.swift
//  Warp
//
//  Created by JSilver on 10/3/26.
//

import Foundation

// What one body proves of its answers: whether it does by itself, and which
// of its own document's declarations the rest leans on. Settled over the
// whole document, since a declaration it leans on may be read after it.
struct AnswerProof: Sendable {
    // MARK: - Property
    let alone: Bool
    let leaning: Set<Name>

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
