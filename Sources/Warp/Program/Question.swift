//
//  Question.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

public struct Question<P: NativeProcedure>: Sendable {
    // The arguments a procedure reads: settled by the row a run sent, with the
    // run as the way back in for a procedure handed a procedure, or offered by
    // name where a caller asks the procedure directly, with no declaration and no
    // run behind them.
    private enum Arguments: Sendable {
        // The sends this procedure declared travel with the run, since the rows they
        // reach are the sender's document's numbers and only a run can say
        // which rows they are.
        case settled(Settled, sends: [Sent], from: Int, Executor)
        case offered([Name: Value])
    }

    // MARK: - Property
    // What this was sent to, or nil where it was sent to nothing. Nil rather
    // than null because a procedure decides for itself what being sent to nothing
    // means: `contains` says false rather than failing.
    public let receiver: Value?

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
    init(receiver: Value? = nil, arguments: [Name: Value] = [:]) {
        self.receiver = receiver
        self.arguments = .offered(arguments)
    }

    init(receiver: Value?, settled: Settled, sends: [Sent], from origin: Int, executor: Executor) {
        self.receiver = receiver
        self.arguments = .settled(settled, sends: sends, from: origin, executor)
    }

    // MARK: - Public
    // What an argument holds, named by the procedure's own key. An argument nobody
    // wrote and one written as null are the same fact here, the same as they
    // are everywhere else.
    //
    // A settled question reads the place the key stands at, since the run
    // ordered the arguments by the declaration this key belongs to. An offered
    // one was asked with no declaration behind it, so there are only names.
    public subscript(key: P.Parameters) -> Value {
        switch arguments {
        case let .settled(settled, _, _, _):
            return settled[key.position]

        case let .offered(offered):
            return offered[key.name] ?? .null
        }
    }

    // Sending a procedure this procedure declared it sends. The link resolved the row
    // and the place each handed argument stands at, so what happens here is
    // indexing twice and looking nothing up; a procedure this one never declared is
    // a procedure that does not compile.
    //
    // The arguments stand in the order the key declared it hands them, which is
    // the order the build read the places off.
    //
    // Synchronous, because a query answers without running and the link
    // refused a query declaring it sends anything that runs.
    public func send(
        _ key: P.Imports,
        to receiver: Value? = nil,
        offering arguments: [Value] = []
    ) throws -> Value {
        guard case let .settled(_, sends, origin, executor) = self.arguments,
            sends.indices.contains(key.position)
        else {
            throw ExecutionError(
                "this procedure sends '\(key.selector)', and this question was asked"
                    + " with no link behind it. A constant settles from"
                    + " procedures that send nothing"
            )
        }

        return try executor.send(
            sends[key.position],
            from: origin,
            to: receiver,
            offering: arguments
        )
    }

    // Running a procedure this procedure was handed. What may be handed is what the
    // link proved answers without running, which a procedure states by declaring the
    // parameter `pure procedure`, so reaching here means the judgement was
    // already made.
    public func call(_ procedure: Value, with arguments: [(name: Name, value: Value)] = []) throws -> Value {
        guard case let .procedure(closure) = procedure else {
            throw ExecutionError(
                "this call names \(procedure.type), and only a procedure can be called"
            )
        }

        guard case let .settled(_, _, _, executor) = self.arguments else {
            throw ExecutionError("this question was asked with no way back into the run")
        }

        return try executor.call(closure, with: arguments)
    }
}
