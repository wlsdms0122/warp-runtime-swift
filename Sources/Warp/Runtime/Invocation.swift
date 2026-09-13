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
public struct Invocation<P: NativeProcedure>: Sendable {
    // MARK: - Property
    public let selector: Name

    // The declaration being sent, so a procedure reads its arguments by the names
    // the declaration gave them.
    public let signature: Signature

    // What this was sent to, or nil where it was sent to nothing.
    public let receiver: Value?

    private let settled: Settled

    // Where the run was when this was sent, as everything it went through to
    // get here. Provenance, not meaning: a procedure does not know the statement it
    // was written in, but a log line and a refusal both want to say where they
    // are.
    public let trace: Trace

    public var environment: (any Environment)? { executor.environment }

    // The variables handed in place, by parameter position.
    private let holds: [(position: Int, handle: Handle)]

    // The sends this procedure declared, in the places it names them at: the row
    // each reaches and where what it hands over stands.
    private let sends: [Sent]

    // Which document numbered them. A procedure's declared sends are numbered the
    // way a call written in a body is, by the document that declared it.
    private let origin: Int

    private let executor: Executor

    // MARK: - Initializer
    init(
        selector: Name,
        signature: Signature,
        receiver: Value?,
        settled: Settled,
        holds: [(position: Int, handle: Handle)],
        sends: [Sent],
        from origin: Int,
        trace: Trace,
        executor: Executor
    ) {
        self.selector = selector
        self.signature = signature
        self.receiver = receiver
        self.settled = settled
        self.holds = holds
        self.sends = sends
        self.origin = origin
        self.trace = trace
        self.executor = executor
    }

    // MARK: - Public
    // What an argument holds, named by the procedure's own key. An argument nobody
    // wrote and one written as null are the same fact here, the same as they
    // are everywhere else.
    public subscript(key: P.Parameters) -> Value {
        settled[key.position]
    }

    // What a parameter handed in place holds now.
    public func held(_ key: P.Parameters) throws -> Value {
        guard let hold = hold(of: key) else {
            throw ExecutionError(
                "'\(selector)' reads '\(key.name)' in place, and it was not handed a variable"
            )
        }

        return try hold.value()
    }

    // Writes a value through the hold a parameter was handed. A native procedure
    // declaring a parameter `inout` answers into the caller's variable this
    // way, and a procedure writing an argument that is not a path is a procedure the
    // link should have refused.
    public func write(_ key: P.Parameters, _ value: Value) throws {
        guard let hold = hold(of: key) else {
            throw ExecutionError(
                "'\(selector)' writes '\(key.name)' in place, and it was not handed a variable"
            )
        }

        try hold.write(value, at: [])
    }

    // Nil for an argument that is absent or null, rather than the empty string
    // stringifying null would give: "unset" and "set to nothing" are different
    // instructions to a caller.
    public func string(_ key: P.Parameters) -> String? {
        switch self[key] {
        case .null:
            return nil

        case let value:
            return Rendering(value).text()
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
    // The label names which piece of this procedure's work the send is, the way it
    // does for a closure, so a refusal from inside says where it happened.
    public func send(
        _ key: P.Imports,
        to receiver: Value? = nil,
        offering arguments: [Value] = [],
        piece label: String? = nil
    ) async throws -> Value {
        guard sends.indices.contains(key.position) else {
            throw ExecutionError("'\(selector)' sends '\(key.selector)', and the link resolved no row for it")
        }

        return try await executor.send(
            sends[key.position],
            from: origin,
            to: receiver,
            offering: arguments,
            at: label.map { name in trace.appending(.piece(name)) } ?? trace
        )
    }

    // Calling a closure the procedure was handed as a value. The label names which
    // piece of the procedure's work this call is, so a refusal from inside says
    // where it happened rather than only which procedure was running.
    public func call(
        _ closure: Closure,
        offering arguments: [(name: Name, value: Value)],
        piece label: String? = nil
    ) async throws -> Value {
        try await executor.call(
            closure,
            offering: arguments,
            at: label.map { name in trace.appending(.piece(name)) } ?? trace
        )
    }

    // MARK: - Private
    private func hold(of key: P.Parameters) -> Handle? {
        holds.first { hold in hold.position == key.position }?.handle
    }
}
