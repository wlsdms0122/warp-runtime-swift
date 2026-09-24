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
    // The row being sent: what a trace and a refusal call it, the declaration
    // its arguments are read by, and the sends it declared, which are its
    // document's numbers.
    private let callee: Linked

    private let settled: Settled

    // Where the run was when this was sent, as everything it went through to
    // get here. Provenance, not meaning: a procedure does not know the statement it
    // was written in, but a log line and a refusal both want to say where they
    // are.
    public let trace: Trace

    public var environment: (any Environment)? { executor.environment }

    // The variables handed in place, by parameter position.
    private let holds: [(position: Int, handle: Handle)]

    private let executor: Executor

    public var selector: Name { callee.label }

    // The declaration being sent, so a procedure reads its arguments by the names
    // the declaration gave them.
    public var signature: Signature { callee.signature }

    // MARK: - Initializer
    init(
        of callee: Linked,
        settled: Settled,
        holds: [(position: Int, handle: Handle)],
        trace: Trace,
        executor: Executor
    ) {
        self.callee = callee
        self.settled = settled
        self.holds = holds
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

    // Nil for an argument that is absent or null. Null spells as `null`, and a
    // caller asking for a string wants what was said rather than that word:
    // "unset" and "set to nothing" are one instruction here.
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
    // The arguments stand at the callee's first positions, as many as the key
    // declared it hands.
    //
    // The label names which piece of this procedure's work the send is, the way it
    // does for a closure, so a refusal from inside says where it happened.
    public func send(
        _ key: P.Imports,
        handing arguments: [Value] = [],
        piece label: String? = nil
    ) async throws -> Value {
        guard callee.sends.indices.contains(key.position) else {
            throw ExecutionError("'\(selector)' sends '\(key.selector)', and the link resolved no row for it")
        }

        return try await executor.send(
            callee.sends[key.position],
            from: callee.origin,
            handing: arguments,
            at: label.map { name in trace.appending(.piece(name)) } ?? trace
        )
    }

    // Calling a closure the procedure was handed as a value. The arguments
    // are handed by position, the way every call hands them. The label names which piece of the procedure's work this call
    // is, so a refusal from inside says where it happened rather than only
    // which procedure was running.
    public func call(
        _ closure: Closure,
        handing arguments: [Value],
        piece label: String? = nil
    ) async throws -> Value {
        try await executor.call(
            closure,
            handing: arguments,
            at: label.map { name in trace.appending(.piece(name)) } ?? trace
        )
    }

    // MARK: - Private
    private func hold(of key: P.Parameters) -> Handle? {
        holds.first { hold in hold.position == key.position }?.handle
    }
}
