//
//  CompiledCode.swift
//  Warp
//
//  Created by JSilver on 11/14/26.
//

import Foundation

// An operation compiled: what it computes in a frame. Synchronous code is
// read where the code holding it runs, with no async frame, and a computation
// with any other argument is answered there with no frame of its own;
// everything else is a closure.
//
// The closure is a payload of this enum, which a call reads with no
// reabstraction thunk, so calling it costs one async frame. It runs on its
// caller's executor, so a call between two of them switches nothing.
enum CompiledCode: Sendable {
    typealias Body = nonisolated(nonsending) @Sendable (inout Activation, Evaluator) async throws -> Value

    case synchronous(SynchronousCode)
    case running(Body)
    case computing(CompiledComputation)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    @inline(__always)
    nonisolated(nonsending) func run(_ activation: inout Activation, _ evaluator: Evaluator) async throws -> Value {
        switch self {
        case let .synchronous(code):
            return try code.run(&activation, evaluator)

        case let .running(body):
            return try await body(&activation, evaluator)

        case let .computing(computation):
            return try await computation.run(&activation, evaluator)
        }
    }

    // MARK: - Private
}
