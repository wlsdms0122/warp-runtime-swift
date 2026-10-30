//
//  UnfoldableProcedure.swift
//  Warp
//
//  Created by JSilver on 9/17/26.
//

import Foundation

// The stand-in, in the table a fold runs against, for a procedure a host
// brought. A constant folds at the build and what it folds to is written
// into the object, so it folds from what every implementation returns the
// same way: a body in the link, read from the text the object is keyed by, and
// the procedures the specification names. What a brought procedure returns is
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
            "'\(label)' is a procedure the host brought, and a constant folds"
                + " from the standard vocabulary and from bodies in the link"
        )
    }

    // MARK: - Private
}
