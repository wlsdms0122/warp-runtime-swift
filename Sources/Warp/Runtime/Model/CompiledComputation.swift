//
//  CompiledComputation.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// A call to a computation compiled: its arguments read in position order, so
// one standing first refuses or fails before one after it is read, and the
// computation answered from them with no frame of its own.
final class CompiledComputation: Sendable {
    // MARK: - Property
    let computation: any Computation

    let first: CompiledCode?
    let second: CompiledCode?
    let rest: [CompiledCode?]

    let returns: LoweredType

    // MARK: - Initializer
    init(_ computation: any Computation, arguments: [CompiledCode?], returning returns: LoweredType) {
        self.computation = computation
        self.first = arguments.count > 0 ? arguments[0] : nil
        self.second = arguments.count > 1 ? arguments[1] : nil
        self.rest = Array(arguments.dropFirst(2))
        self.returns = returns
    }

    // MARK: - Public
    @inline(__always)
    nonisolated(nonsending) func run(_ activation: inout Activation, _ evaluator: Evaluator) async throws -> Value {
        let first = try await first?.run(&activation, evaluator)
        let second = try await second?.run(&activation, evaluator)
        var rest: [Value?] = []

        for argument in self.rest {
            rest.append(try await argument?.run(&activation, evaluator))
        }

        return try evaluator.compute(
            computation,
            given: Given(first: first, second: second, rest: rest),
            returning: returns
        )
    }

    // MARK: - Private
}
