//
//  Effect.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A procedure implemented natively that is handed what a query is and two
// things more: the caller's variable for a parameter handed in place, read and
// written as it runs, and the environment the host handed the run. Anything
// with a clock, a device or another process behind it is one. Same
// declaration, same call as a query; holding those two, its declaration cannot
// say it is const and it cannot be asked inside a condition.
//
// An effect is declared, not embedded. The grammar stays closed. A module adds
// vocabulary, never a new kind of expression, so nothing installed can quietly
// redefine what `loop` means.
public protocol Effect: NativeProcedure {
    nonisolated(nonsending) func run(_ invocation: Invocation<Self>) async throws -> Value

    // The entry a run sends through. The default is compiled where the
    // procedure's type is concrete, so the invocation is made for that type
    // and not looked up by it.
    nonisolated(nonsending) func perform(_ invoked: Invoked) async throws -> Value
}

extension Effect {
    @inlinable
    public nonisolated(nonsending) func perform(_ invoked: Invoked) async throws -> Value {
        try await run(Invocation(invoked))
    }
}
