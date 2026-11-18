//
//  Question.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

public struct Question<P: NativeProcedure>: Sendable {
    // MARK: - Property
    @usableFromInline
    let asked: Asked

    // MARK: - Initializer
    @inlinable
    init(_ asked: Asked) {
        self.asked = asked
    }

    // MARK: - Public
    // What an argument holds, named by the procedure's own key: the place the
    // key stands at, since the run ordered the arguments by the declaration
    // this key belongs to.
    @inlinable
    public subscript(key: P.Parameters) -> Value {
        asked.arguments[key.position]
    }

    // Sending a procedure this procedure declared it sends, the way
    // `Invocation.send` does. The build refused a query declaring it sends
    // anything that runs, so what it reaches returns data.
    public func send(
        _ key: P.Imports,
        handing arguments: [Value] = []
    ) async throws -> Value {
        try await asked.evaluator.send(
            try asked.callee.sent(key.position, as: key.selector),
            from: asked.callee.origin,
            handing: arguments,
            at: asked.location
        )
    }

    // Calling a closure this procedure was handed as a value. What may be
    // handed is what the build proved is const, which a
    // procedure states by declaring the parameter `const Procedure`. The
    // arguments are handed by position, the way every call hands them.
    public func call(_ closure: Closure, handing arguments: [Value] = []) async throws -> Value {
        try await asked.evaluator.call(closure, handing: arguments, at: asked.location)
    }

    // MARK: - Private
}
