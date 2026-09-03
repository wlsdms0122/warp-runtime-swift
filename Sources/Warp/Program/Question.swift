//
//  Question.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

public struct Question: Sendable {
    // The arguments a word reads: settled by the row a run sent, with the
    // run as the way back in for a word handed a procedure, or offered by
    // name where a caller asks the word directly, with no declaration and no
    // run behind them.
    private enum Arguments: Sendable {
        case settled(Settled, Executor)
        case offered([String: Value])
    }

    // MARK: - Property
    // What this was sent to, or nil where it was sent to nothing. Nil rather
    // than null because a word decides for itself what being sent to nothing
    // means: `contains` says false rather than failing.
    public let receiver: Value?

    // The way back in travels with the arguments rather than being handed to
    // `Query.evaluate`: most words never call anything, and a parameter every
    // word declares to serve the few that do is a parameter in the wrong
    // place.
    private let arguments: Arguments

    // MARK: - Initializer
    public init(receiver: Value? = nil, arguments: [String: Value] = [:]) {
        self.receiver = receiver
        self.arguments = .offered(arguments)
    }

    init(receiver: Value?, settled: Settled, executor: Executor) {
        self.receiver = receiver
        self.arguments = .settled(settled, executor)
    }

    // MARK: - Public
    // What a named argument holds. An argument nobody wrote and one written as
    // null are the same fact here, the same as they are everywhere else.
    public subscript(name: String) -> Value {
        switch arguments {
        case let .settled(settled, _):
            return settled[name]

        case let .offered(offered):
            return offered[name] ?? .null
        }
    }

    // Running a procedure this word was handed. What may be handed is what the
    // link proved answers without running, which a word states by declaring the
    // parameter `pure procedure`, so reaching here means the judgement was
    // already made.
    public func call(_ procedure: Value, with arguments: [(name: String, value: Value)] = []) throws -> Value {
        guard case let .procedure(closure) = procedure else {
            throw ExecutionError(
                "this call names \(procedure.type), and only a procedure can be called"
            )
        }

        guard case let .settled(_, executor) = self.arguments else {
            throw ExecutionError("this question was asked with no way back into the run")
        }

        return try executor.call(closure, with: arguments)
    }
}
