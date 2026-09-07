//
//  Question.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

public struct Question<W: Word>: Sendable {
    // The arguments a word reads: settled by the row a run sent, with the
    // run as the way back in for a word handed a procedure, or offered by
    // name where a caller asks the word directly, with no declaration and no
    // run behind them.
    private enum Arguments: Sendable {
        case settled(Settled, Executor)
        case offered([Name: Value])
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

    // The rows this word's declared sends reach, in the places the word names
    // them at. Empty for a question asked with no link behind it.
    private let sends: [Int]

    // MARK: - Initializer
    // Asking a word with no declaration and no run behind it: the link judging
    // a constant against the word that will settle it. Not a door out of the
    // package, because what makes a word answerable is the link that took its
    // declaration, and a question built beside that skips it.
    init(receiver: Value? = nil, arguments: [Name: Value] = [:]) {
        self.receiver = receiver
        self.arguments = .offered(arguments)
        self.sends = []
    }

    init(receiver: Value?, settled: Settled, sends: [Int], executor: Executor) {
        self.receiver = receiver
        self.arguments = .settled(settled, executor)
        self.sends = sends
    }

    // MARK: - Public
    // What an argument holds, named by the word's own key. An argument nobody
    // wrote and one written as null are the same fact here, the same as they
    // are everywhere else.
    //
    // A settled question reads the place the key stands at, since the run
    // ordered the arguments by the declaration this key belongs to. An offered
    // one was asked with no declaration behind it, so there are only names.
    public subscript(key: W.Parameters) -> Value {
        switch arguments {
        case let .settled(settled, _):
            return settled[key.position]

        case let .offered(offered):
            return offered[key.name] ?? .null
        }
    }

    // Sending a word this word declared it sends. The link resolved the row,
    // so what happens here is an index and not a lookup, and a word this one
    // never declared is a word that does not compile.
    //
    // Synchronous, because a query answers without running and the link
    // refused a query declaring it sends anything that runs.
    public func send(
        _ key: W.Imports,
        to receiver: Value? = nil,
        offering arguments: [(name: Name, value: Value)] = []
    ) throws -> Value {
        guard case let .settled(_, executor) = self.arguments, sends.indices.contains(key.position) else {
            throw ExecutionError(
                "this word sends '\(key.selector)', and this question was asked"
                    + " with no link behind it. A constant settles from words that send nothing"
            )
        }

        return try executor.send(sends[key.position], to: receiver, offering: arguments)
    }

    // Running a procedure this word was handed. What may be handed is what the
    // link proved answers without running, which a word states by declaring the
    // parameter `pure procedure`, so reaching here means the judgement was
    // already made.
    public func call(_ procedure: Value, with arguments: [(name: Name, value: Value)] = []) throws -> Value {
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
