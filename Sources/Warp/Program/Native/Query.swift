//
//  Query.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A procedure implemented natively that is handed what its call wrote and
// nothing the caller or the host holds. `count`, `contains`, whatever a module
// ships. Its declaration may say it is const, which is what lets it be asked
// inside a condition and while a constant folds.
//
// It carries no name and no signature. Both belong to the `Procedure` that has
// this as its implementation. The name is the key its module declares it under,
// the same as any other declaration, and the signature is what a call site is
// checked against whichever way the body is written.
public protocol Query: NativeProcedure {
    nonisolated(nonsending) func evaluate(_ question: Question<Self>) async throws -> Value

    // The entry a run asks through. The default is compiled where the
    // procedure's type is concrete, so the question is made for that type and
    // not looked up by it.
    nonisolated(nonsending) func answer(_ asked: Asked) async throws -> Value
}

extension Query {
    @inlinable
    public nonisolated(nonsending) func answer(_ asked: Asked) async throws -> Value {
        try await evaluate(Question(asked))
    }
}
