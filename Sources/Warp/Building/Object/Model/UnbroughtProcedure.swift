//
//  UnbroughtProcedure.swift
//  Warp
//
//  Created by JSilver on 9/10/26.
//

import Foundation

// The stand-in for a procedure whose code a compile was not handed. A compiled
// document names the procedures it left to native code and holds none of it, and a
// compile runs one only where it folds a constant through it, so a row nothing
// folds stands here rather than stopping the compile. A link is another
// matter: it states what the whole run may call, and never lays one down.
//
// Two of them, one to a door, so a row that answers by running still says so.
// What the run reads off a row is which door it answers through, and a row
// standing in for an effect that claimed to be a query is a row the executor
// would read the wrong way.
struct UnbroughtProcedure: Query {
    typealias Parameters = NoParameters

    // MARK: - Property
    let label: Name

    // MARK: - Initializer
    init(_ label: Name) {
        self.label = label
    }

    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        throw UnbroughtProcedure.refusal(label)
    }

    static func refusal(_ label: Name) -> ExecutionError {
        ExecutionError(
            "'\(label)' is implemented in native code and this compile was handed none."
                + " A constant folding through it settles from the code the run will use"
        )
    }

    // MARK: - Private
}
