//
//  Arithmetic.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The numeric operations. The procedures satisfying `Standard.Numeric` for
// `Int` and for `Double` send here, so what a sum and a quotient share is
// written once: a divisor of zero, and which return values fall off the edge.
//
// Both sides are the one type the declaration satisfies `Standard.Numeric`
// for, and so is the return value, except a quotient, which is a `Double` even
// between two `Int`s.
//
// `Int` is 64 bits, so an `Int` return value can fall off its edge. That is a
// fault of the program, not a condition of its data: an overflow and a divisor
// of zero stop the run the way an index past the end does, without the
// recoverable marker a `try` reads.
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

    // Whether a zero on the right has no result.
    private var divides: Bool {
        operation == .dividedBy || operation == .remainder
    }

    private var zeroDivisor: ExecutionError {
        ExecutionError("\(procedure) has no result for a zero divisor")
    }

    // MARK: - Initializer
    init(_ operation: Operation, implementing procedure: String) {
        self.operation = operation
        self.procedure = procedure
    }

    // MARK: - Public
    func result(_ first: Value, _ operand: Value) throws -> Value {
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
    // The return value for two `Int`s: an `Int`, except a quotient.
    private func whole(_ left: Int, _ right: Int) throws -> Value {
        let reported: (partialValue: Int, overflow: Bool)

        switch operation {
        case .plus:
            reported = left.addingReportingOverflow(right)

        case .minus:
            reported = left.subtractingReportingOverflow(right)

        case .times:
            reported = left.multipliedReportingOverflow(by: right)

        case .dividedBy:
            return .double(try real(Double(left), Double(right)))

        // A remainder is smaller in size than its divisor, so it always fits an `Int`.
        // The one divisor that trips the hardware's division (`Int.min % -1`)
        // still has the result 0, so it is returned directly.
        case .remainder:
            guard right != 0 else { throw zeroDivisor }

            return .int(right == -1 ? 0 : left % right)
        }

        guard !reported.overflow else {
            throw ExecutionError(
                "\(procedure) of \(left) and \(right) overflows Int"
            )
        }

        return .int(reported.partialValue)
    }

    // The return value for two `Double`s, which the door every return value
    // crosses refuses where it has no finite value.
    private func real(_ left: Double, _ right: Double) throws -> Double {
        guard !divides || right != 0 else { throw zeroDivisor }

        switch operation {
        case .plus:
            return left + right

        case .minus:
            return left - right

        case .times:
            return left * right

        case .dividedBy:
            return left / right

        // Truncating toward zero, the same as the `Int` return value, so both
        // take the dividend's sign.
        case .remainder:
            return left.truncatingRemainder(dividingBy: right)
        }
    }
}
