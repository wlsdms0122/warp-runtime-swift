//
//  UnsettledWord.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

// The stand-in for a written body in the tables the link's own settling reads.
// A native word answers at the link; a written body is itself still being
// resolved beside the constants it may read, so a constant that ran one would
// be a circle with no start. The fact lives in the table (the word is there,
// judged and named, and answers with the refusal) rather than in a flag every
// resolver would have to carry.
struct UnsettledWord: Query {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        throw ExecutionError(
            "this word has a written body, which runs after the link."
                + " A constant settles from native words alone"
        )
    }

    // MARK: - Private
}
