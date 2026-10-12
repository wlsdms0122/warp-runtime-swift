//
//  Arithmetic.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The numeric operations. The procedures answering `Standard.Numeric` for
// `Int` and for `Double` send here, so what a sum and a quotient share is
// written once: a divisor of zero, and which answers fall off the edge.
//
// Both sides are the one type the declaration answers for, and so is the
// answer, except a quotient, which is a fraction even between wholes.
//
// `Int` is 64 bits, so a whole answer can fall off its edge. That is a
// fault of the program, not a condition of its data: an overflow and a divisor
// of zero stop the run the way an index past the end does, without the
// recoverable marker an `attempt` reads.
struct Arithmetic: Sendable {
    enum Operation: Sendable, Equatable {
        case plus
        case minus
        case times
        case dividedBy
        case remainder
    }

    // MARK: - Property
    private let operation: Operation

    // The declared spelling, which a refusal names.
    private let procedure: String

    // Whether a zero on the right has no answer.
    private var divides: Bool {
        operation == .dividedBy || operation == .remainder
    }

    private var zeroDivisor: ExecutionError {
        ExecutionError("\(procedure) has no answer for a zero divisor")
    }

    // MARK: - Initializer
    init(_ operation: Operation, answering procedure: String) {
        self.operation = operation
        self.procedure = procedure
    }

    // MARK: - Public
    func answer(_ first: Value, _ operand: Value) throws -> Value {
        switch (first, operand) {
        case let (.int(left), .int(right)):
            return try whole(left, right)

        case let (.double(left), .double(right)):
            return .double(try real(left, right))

        default:
            throw ExecutionError("\(procedure) asks two numbers of one type")
        }
    }

    // MARK: - Private
    // The answer two wholes have: a whole, except a quotient.
    private func whole(_ left: Int, _ right: Int) throws -> Value {
        let answered: (partialValue: Int, overflow: Bool)

        switch operation {
        case .plus:
            answered = left.addingReportingOverflow(right)

        case .minus:
            answered = left.subtractingReportingOverflow(right)

        case .times:
            answered = left.multipliedReportingOverflow(by: right)

        case .dividedBy:
            return .double(try real(Double(left), Double(right)))

        // A remainder is smaller in size than its divisor, so it always fits an `Int`.
        // The one divisor that trips the hardware's division (`Int.min % -1`)
        // still has the answer 0, so it is answered directly.
        case .remainder:
            guard right != 0 else { throw zeroDivisor }

            return .int(right == -1 ? 0 : left % right)
        }

        guard !answered.overflow else {
            throw ExecutionError(
                "\(procedure) of \(left) and \(right) overflows Int"
            )
        }

        return .int(answered.partialValue)
    }

    // The answer two fractions have. Infinity is a fraction the arithmetic
    // can reach and no document can carry, so it has no answer.
    private func real(_ left: Double, _ right: Double) throws -> Double {
        guard !divides || right != 0 else { throw zeroDivisor }

        let answered: Double

        switch operation {
        case .plus:
            answered = left + right

        case .minus:
            answered = left - right

        case .times:
            answered = left * right

        case .dividedBy:
            answered = left / right

        // Truncating toward zero, the same as the whole answer, so both take
        // the dividend's sign.
        case .remainder:
            answered = left.truncatingRemainder(dividingBy: right)
        }

        guard answered.isFinite else {
            throw ExecutionError(
                "\(procedure) of \(left) and \(right) has no finite answer"
            )
        }

        return answered
    }
}
