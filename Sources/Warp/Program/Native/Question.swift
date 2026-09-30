//
//  Question.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

public struct Question<P: NativeProcedure>: Sendable {
    // The arguments a procedure reads: settled by the row a run sent, with the
    // run as the way back in for a procedure handed a procedure, or given by
    // name where a caller asks the procedure directly, with no declaration and no
    // run behind them.
    private enum Arguments: Sendable {
        // The row being asked travels with the run: the sends it declared are
        // its document's numbers, and only a run can say which rows they are.
        case settled(Settled, of: Linked, Executor)
        case given([Name: Value])
    }

    // MARK: - Property
    // The way back in travels with the arguments rather than being handed to
    // `Query.evaluate`: most procedures never call anything, and a parameter every
    // procedure declares to serve the few that do is a parameter in the wrong
    // place.
    private let arguments: Arguments

    // MARK: - Initializer
    // Asking a procedure with no declaration and no run behind it: the link judging
    // a constant against the procedure that will settle it. Not a door out of the
    // package, because what makes a procedure answerable is the link that took its
    // declaration, and a question built beside that skips it.
    init(arguments: [Name: Value] = [:]) {
        self.arguments = .given(arguments)
    }

    init(settled: Settled, of callee: Linked, executor: Executor) {
        self.arguments = .settled(settled, of: callee, executor)
    }

    // MARK: - Public
    // What an argument holds, named by the procedure's own key.
    //
    // A settled question reads the place the key stands at, since the run
    // ordered the arguments by the declaration this key belongs to. A given
    // one was asked with no declaration behind it, so there are only names,
    // and a name it was not given reads as null.
    public subscript(key: P.Parameters) -> Value {
        switch arguments {
        case let .settled(settled, _, _):
            return settled[key.position]

        case let .given(given):
            return given[key.name] ?? .null
        }
    }

    // Sending a procedure this procedure declared it sends, the way
    // `Invocation.send` does. The link refused a query declaring it sends
    // anything that runs.
    public func send(
        _ key: P.Imports,
        handing arguments: [Value] = []
    ) async throws -> Value {
        guard case let .settled(_, callee, executor) = self.arguments,
            callee.sends.indices.contains(key.position)
        else {
            throw ExecutionError(
                "this procedure sends '\(key.selector)', and this question was asked"
                    + " with no link behind it. A constant settles from"
                    + " procedures that send nothing"
            )
        }

        return try await executor.send(
            callee.sends[key.position],
            from: callee.origin,
            handing: arguments
        )
    }

    // Calling a closure this procedure was handed as a value. What may be
    // handed is what the link proved answers without running, which a
    // procedure states by declaring the parameter `const procedure`. The
    // arguments are handed by position, the way every call hands them.
    public func call(_ closure: Closure, handing arguments: [Value] = []) async throws -> Value {
        guard case let .settled(_, _, executor) = self.arguments else {
            throw ExecutionError("this question was asked with no way back into the run")
        }

        return try await executor.call(closure, handing: arguments, at: Trace())
    }

    // MARK: - Private
}
