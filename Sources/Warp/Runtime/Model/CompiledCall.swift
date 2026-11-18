//
//  CompiledCall.swift
//  Warp
//
//  Created by JSilver on 11/14/26.
//

import Foundation

// A call compiled against the row it reaches, for a call through a contract
// whose row the run picks: handed the value read first to pick the row,
// where one was read, and what fills the callee's type parameters.
//
// The closure is a field of this struct, which a call reads with no
// reabstraction thunk.
struct CompiledCall: Sendable {
    typealias Body = nonisolated(nonsending) @Sendable (inout Activation, Evaluator, Value?, [Name: LoweredType]) async throws -> Value

    // MARK: - Property
    let run: Body

    // MARK: - Initializer
    init(_ run: @escaping Body) {
        self.run = run
    }

    // MARK: - Public
    // MARK: - Private
}
