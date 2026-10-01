//
//  UnfoldableProcedure.swift
//  Warp
//
//  Created by JSilver on 9/17/26.
//

import Foundation

// The stand-in, in the table a fold runs against, for a procedure a caller
// brought. A constant settles at the build and what it settles to is written
// into the object, so it settles from what every implementation answers the
// same way: a body in the link, read from the text the object is keyed by, and
// the procedures the specification names. What a brought procedure answers is
// its code's, and nothing the object carries says which code that was.
//
// It stands in the folding table alone. The row a run reads holds the
// procedure itself, because calling one while the program runs is what a
// vocabulary is for.
struct UnfoldableProcedure: Query {
    typealias Parameters = NoParameters

    // MARK: - Property
    let label: Name

    // MARK: - Initializer
    init(_ label: Name) {
        self.label = label
    }

    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        throw ExecutionError(
            "'\(label)' is a procedure the host brought, and a constant settles"
                + " from the standard vocabulary and from bodies in the link"
        )
    }

    // MARK: - Private
}
