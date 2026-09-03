//
//  Invocation.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// An effect's door into the run. The arguments arrive settled, the way a
// body's do; what an effect has beyond a query is the way to write a variable
// it was handed in place, to call a closure it was handed, and to reach the
// environment.
public struct Invocation: Sendable {
    // MARK: - Property
    public let selector: String

    // The declaration being sent, so a word reads its arguments by the names
    // the declaration gave them.
    public let signature: Signature

    // What this was sent to, or nil where it was sent to nothing.
    public let receiver: Value?

    private let settled: Settled

    // Where the run was when this was sent, as everything it went through to
    // get here. Provenance, not meaning: a word does not know the statement it
    // was written in, but a log line and a refusal both want to say where they
    // are.
    public let trace: Trace

    public var environment: (any Environment)? { executor.environment }

    // The variables handed in place, by parameter position.
    private let holds: [(position: Int, handle: Handle)]
    private let executor: Executor

    // MARK: - Initializer
    init(
        selector: String,
        signature: Signature,
        receiver: Value?,
        settled: Settled,
        holds: [(position: Int, handle: Handle)],
        trace: Trace,
        executor: Executor
    ) {
        self.selector = selector
        self.signature = signature
        self.receiver = receiver
        self.settled = settled
        self.holds = holds
        self.trace = trace
        self.executor = executor
    }

    // MARK: - Public
    // What a named argument holds. An argument nobody wrote and one written as
    // null are the same fact here, the same as they are everywhere else.
    public subscript(name: String) -> Value {
        settled[name]
    }

    // What a parameter handed in place holds now.
    public func held(_ name: String) throws -> Value {
        guard let hold = hold(of: name) else {
            throw ExecutionError(
                "'\(selector)' reads '\(name)' in place, and it was not handed a variable"
            )
        }

        return try hold.value()
    }

    // Writes a value through the hold a parameter was handed. A native word
    // declaring a parameter `inout` answers into the caller's variable this
    // way, and a word writing an argument that is not a path is a word the
    // link should have refused.
    public func write(_ name: String, _ value: Value) throws {
        guard let hold = hold(of: name) else {
            throw ExecutionError(
                "'\(selector)' writes '\(name)' in place, and it was not handed a variable"
            )
        }

        try hold.write(value, at: [])
    }

    // Nil for an argument that is absent or null, rather than the empty string
    // stringifying null would give: "unset" and "set to nothing" are different
    // instructions to a caller.
    public func string(_ name: String) -> String? {
        switch self[name] {
        case .null:
            return nil

        case let value:
            return Rendering(value).text()
        }
    }

    // Calling a closure the word was handed as a value. The label names which
    // piece of the word's work this call is, so a refusal from inside says
    // where it happened rather than only which word was running.
    public func call(
        _ closure: Closure,
        offering arguments: [(name: String, value: Value)],
        piece label: String? = nil
    ) async throws -> Value {
        try await executor.call(
            closure,
            offering: arguments,
            at: label.map { name in trace.appending(.piece(name)) } ?? trace
        )
    }

    // MARK: - Private
    private func hold(of name: String) -> Handle? {
        guard let position = settled.position(of: name) else { return nil }

        return holds.first { hold in hold.position == position }?.handle
    }
}
