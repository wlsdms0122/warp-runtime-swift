//
//  Invocation.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// What an effect is handed in the run. The arguments arrive by position, the
// way a body's do; what an effect has beyond a query is the way to write a
// variable it was handed in place, to call a closure it was handed, and to
// reach the environment.
public struct Invocation<P: NativeProcedure>: Sendable {
    // MARK: - Property
    @usableFromInline
    let invoked: Invoked

    public var trace: Trace { invoked.trace }

    public var environment: (any Environment)? { evaluator.environment }

    public var selector: Name { callee.label }

    private var callee: Linked { invoked.callee }
    private var holds: [(position: Int, handle: Handle)] { invoked.holds }
    private var evaluator: Evaluator { invoked.evaluator }

    // MARK: - Initializer
    @inlinable
    init(_ invoked: Invoked) {
        self.invoked = invoked
    }

    // MARK: - Public
    // What an argument holds, named by the procedure's own key.
    @inlinable
    public subscript(key: P.Parameters) -> Value {
        invoked.arguments[key.position]
    }

    // What a parameter handed in place holds now.
    public func held(_ key: P.Parameters) throws -> Value {
        guard let hold = hold(of: key) else {
            throw RunRefused(
                "'\(selector)' reads '\(key.name)' in place, and it was not handed a variable"
            )
        }

        return try hold.value()
    }

    // Writes a value through the hold a parameter was handed. A native procedure
    // declaring a parameter `inout` writes into the caller's variable this
    // way. A link hands such a parameter a path, so one that was handed none
    // is refused here. What the host writes is a value from outside, so it
    // comes in through the door the parameter's type keeps.
    public func write(_ key: P.Parameters, _ value: Value) throws {
        guard let hold = hold(of: key) else {
            throw RunRefused(
                "'\(selector)' writes '\(key.name)' in place, and it was not handed a variable"
            )
        }

        let slot = callee.slots[key.position]

        try hold.write(
            try slot.type.slotUnwrapped.settling(outside: value, at: "'\(key.name)'", in: evaluator.loweredTypes),
            at: []
        )
    }

    // Nil for an argument that is null. Null spells as `null`, and a caller
    // asking for a string wants what was said rather than that word.
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
    // The arguments stand at the callee's positions, as many as the key
    // declared it hands.
    //
    // The label names which piece of this procedure's work the send is, the way it
    // does for a closure, so a refusal from inside says where it happened.
    public func send(
        _ key: P.Imports,
        handing arguments: [Value] = [],
        piece label: String? = nil
    ) async throws -> Value {
        try await evaluator.send(
            try callee.sent(key.position, as: key.selector),
            from: callee.origin,
            handing: arguments,
            at: .trace(label.map { name in trace.appending(.piece(name)) } ?? trace)
        )
    }

    // Calling a closure this procedure was handed as a value. The arguments
    // are handed by position, the way every call hands them. The label names
    // which piece of the procedure's work this call is, so a refusal from
    // inside says where it happened rather than only which procedure was
    // running.
    public func call(
        _ closure: Closure,
        handing arguments: [Value] = [],
        piece label: String? = nil
    ) async throws -> Value {
        try await evaluator.call(
            closure,
            handing: arguments,
            at: .trace(label.map { name in trace.appending(.piece(name)) } ?? trace)
        )
    }

    // MARK: - Private
    private func hold(of key: P.Parameters) -> Handle? {
        holds.first { hold in hold.position == key.position }?.handle
    }
}
