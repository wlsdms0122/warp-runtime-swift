//
//  Invoked.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// What a run hands an effect it sends, before it is an invocation of any one
// procedure's type.
public struct Invoked: Sendable {
    // MARK: - Property
    // The row being sent: what a trace and a refusal call it, the declaration
    // its arguments are read by, and the sends it declared, which are its
    // document's numbers.
    let callee: Linked

    @usableFromInline
    let arguments: ArgumentList

    // Where the run was when this was sent, as everything it went through to
    // get here. Provenance, not meaning: a procedure does not know the
    // statement it was written in, but a log line and a refusal both want to
    // say where they are.
    let trace: Trace

    // The variables handed in place, by parameter position.
    let holds: [(position: Int, handle: Handle)]

    let evaluator: Evaluator

    // MARK: - Initializer
    init(
        of callee: Linked,
        arguments: ArgumentList,
        holds: [(position: Int, handle: Handle)],
        trace: Trace,
        evaluator: Evaluator
    ) {
        self.callee = callee
        self.arguments = arguments
        self.holds = holds
        self.trace = trace
        self.evaluator = evaluator
    }

    // MARK: - Public
    // MARK: - Private
}
