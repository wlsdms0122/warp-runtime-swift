//
//  Question.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

public struct Question<P: NativeProcedure>: Sendable {
    // MARK: - Property
    // The arguments a procedure reads, settled by the row a run sent. The row
    // being asked travels with the run: the sends it declared are its
    // document's numbers, and only a run can say which rows they are.
    private let settled: Settled
    private let callee: Linked
    private let evaluator: Evaluator

    // MARK: - Initializer
    init(settled: Settled, of callee: Linked, evaluator: Evaluator) {
        self.settled = settled
        self.callee = callee
        self.evaluator = evaluator
    }

    // MARK: - Public
    // What an argument holds, named by the procedure's own key: the place the
    // key stands at, since the run ordered the arguments by the declaration
    // this key belongs to.
    public subscript(key: P.Parameters) -> Value {
        settled[key.position]
    }

    // Sending a procedure this procedure declared it sends, the way
    // `Invocation.send` does. The build refused a query declaring it sends
    // anything that runs.
    public func send(
        _ key: P.Imports,
        handing arguments: [Value] = []
    ) async throws -> Value {
        try await evaluator.send(
            try callee.sent(key.position, as: key.selector),
            from: callee.origin,
            handing: arguments
        )
    }

    // Calling a closure this procedure was handed as a value. What may be
    // handed is what the build proved answers without running, which a
    // procedure states by declaring the parameter `const Procedure`. The
    // arguments are handed by position, the way every call hands them.
    public func call(_ closure: Closure, handing arguments: [Value] = []) async throws -> Value {
        try await evaluator.call(closure, handing: arguments, at: Trace())
    }

    // MARK: - Private
}
