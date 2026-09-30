//
//  UnsettledProcedure.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

// The stand-in for a written body in the tables the link's own settling reads.
// A native procedure answers at the link; a written body is itself still being
// resolved beside the constants it may read, so a constant that ran one would
// be a cycle with no start. The fact lives in the table (the procedure is there,
// judged and named, and answers with the refusal) rather than in a flag every
// resolver would have to carry.
struct UnsettledProcedure: Query {
    typealias Parameters = NoParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        throw ExecutionError(
            "this procedure's body is being resolved beside the constants it"
                + " may read, so a constant that runs it is a circle with no start"
        )
    }

    // MARK: - Private
}
