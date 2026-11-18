//
//  SynchronousComputation.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// A call to a computation whose every argument is synchronous code,
// compiled: its arguments read in position order, so one standing first
// refuses or fails before one after it is read, and the computation answered
// from them with no async frame.
final class SynchronousComputation: Sendable {
    // MARK: - Property
    let computation: any Computation

    let first: SynchronousCode?
    let second: SynchronousCode?
    let rest: [SynchronousCode?]

    let returns: LoweredType

    // MARK: - Initializer
    init(_ computation: any Computation, arguments: [SynchronousCode?], returning returns: LoweredType) {
        self.computation = computation
        self.first = arguments.count > 0 ? arguments[0] : nil
        self.second = arguments.count > 1 ? arguments[1] : nil
        self.rest = Array(arguments.dropFirst(2))
        self.returns = returns
    }

    // MARK: - Public
    func run(_ activation: inout Activation, _ evaluator: Evaluator) throws -> Value {
        let first = try first?.run(&activation, evaluator)
        let second = try second?.run(&activation, evaluator)
        var rest: [Value?] = []

        for argument in self.rest {
            rest.append(try argument?.run(&activation, evaluator))
        }

        return try evaluator.compute(computation, given: Given(first: first, second: second, rest: rest), returning: returns)
    }

    // The same, where the argument at `moving.position` reads the slot of a
    // variable for the last time before the statement writes it: its value
    // moves out of the slot, and the computation is handed the arguments to
    // keep.
    func handing(
        _ activation: inout Activation,
        _ evaluator: Evaluator,
        moving: (position: Int, slot: Int)
    ) throws -> Value {
        let first = try Self.read(first, at: 0, moving: moving, in: &activation, evaluator)
        let second = try Self.read(second, at: 1, moving: moving, in: &activation, evaluator)
        var rest: [Value?] = []

        for (offset, argument) in self.rest.enumerated() {
            rest.append(try Self.read(argument, at: offset + 2, moving: moving, in: &activation, evaluator))
        }

        return try evaluator.compute(
            computation,
            taking: Given(first: consume first, second: consume second, rest: rest),
            returning: returns
        )
    }

    // MARK: - Private
    private static func read(
        _ argument: SynchronousCode?,
        at position: Int,
        moving: (position: Int, slot: Int),
        in activation: inout Activation,
        _ evaluator: Evaluator
    ) throws -> Value? {
        guard position != moving.position else { return try activation.take(moving.slot) }

        return try argument?.run(&activation, evaluator)
    }
}
