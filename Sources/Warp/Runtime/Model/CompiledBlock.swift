//
//  CompiledBlock.swift
//  Warp
//
//  Created by JSilver on 11/14/26.
//

import Foundation

// A list of instructions compiled, one statement each. The list is run where the construct holding it runs,
// so entering it is no call of its own.
struct CompiledBlock: Sendable {
    // MARK: - Property
    let statements: [CompiledStatement]

    // MARK: - Initializer
    init(_ statements: [CompiledStatement]) {
        self.statements = statements
    }

    // MARK: - Public
    // What the last statement gave: null, but for a body's last statement
    // where it is a `return`, which gives what it returns.
    @inline(__always)
    @discardableResult
    nonisolated(nonsending) func run(_ activation: inout Activation, _ evaluator: Evaluator) async throws -> Value {
        var last = Value.null

        for statement in statements {
            last = try await statement.run(&activation, evaluator)
        }

        return last
    }

    // MARK: - Private
}
