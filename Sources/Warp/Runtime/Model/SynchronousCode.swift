//
//  SynchronousCode.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Code with no suspension point: a literal, a slot, a slot path, and a
// computation whose every argument is such code. A slot holding a hold reads
// through it, the one way a frame reads a path, which says why it did not
// land.
enum SynchronousCode: Sendable {
    case literal(Value)
    case slot(Int)
    case path(CompiledPath)
    case computing(SynchronousComputation)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    @inline(__always)
    func run(_ activation: inout Activation, _ evaluator: Evaluator) throws -> Value {
        switch self {
        case let .literal(value):
            return value

        case let .slot(slot):
            guard case let .value(value) = activation.cells[slot] else {
                return try activation.value(at: Address(slot: slot, steps: []))
            }

            return value

        case let .path(path):
            return try path.read(activation)

        case let .computing(computation):
            return try computation.run(&activation, evaluator)
        }
    }

    // MARK: - Private
}
