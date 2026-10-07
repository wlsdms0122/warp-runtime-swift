//
//  Arithmetic.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The numeric operations. Five procedures send here, so what a sum and a quotient
// share is written once: which pairs are numbers at all, where the whole path
// ends and the fraction path begins, and which answers fall off the edge.
//
// Ints stay ints, so `2 plus 2` answers 4 rather than 4.0. Division is the
// exception, because a quotient is not generally whole.
//
// `int` is 64 bits, so a whole answer can fall off its edge. That is a
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
    private var procedure: String { "Standard.Math.\(operation)" }

    // Whether a zero on the right has no answer. Both read a divisor, and both
    // are asked before the whole path so the check cannot be walked around.
    private var divides: Bool {
        operation == .dividedBy || operation == .remainder
    }

    // MARK: - Initializer
    init(_ operation: Operation) {
        self.operation = operation
    }

    // MARK: - Public
    func answer(_ first: Value, _ operand: Value) throws -> Value {
        guard let left = number(first), let right = number(operand) else {
            throw ExecutionError("\(procedure) asks two numbers")
        }

        // Zero by worth, whichever spelling carries it. The divisor is judged
        // before any conversion, so the check does not lean on what a fraction
        // can hold.
        guard !divides || !operand.matches(.int(0)) else {
            throw ExecutionError("\(procedure) has no answer for a zero divisor")
        }

        if
            case let .int(leftWhole) = first,
            case let .int(rightWhole) = operand,
            let answered = try whole(leftWhole, rightWhole)
        {
            return .int(answered)
        }

        let answered = real(left, right)

        // The line the whole path holds with its edge. Infinity is a fraction
        // the arithmetic can reach and no document can carry, so answering it
        // would mint a value that exists only until someone writes it down.
        guard answered.isFinite else {
            throw ExecutionError(
                "\(procedure) of \(left) and \(right) has no finite answer"
            )
        }

        return .double(answered)
    }

    // MARK: - Private
    // The whole answer two wholes have, or nil where the operation has none:
    // a quotient is a fraction even between wholes.
    private func whole(_ left: Int, _ right: Int) throws -> Int? {
        let answered: (partialValue: Int, overflow: Bool)

        switch operation {
        case .plus:
            answered = left.addingReportingOverflow(right)

        case .minus:
            answered = left.subtractingReportingOverflow(right)

        case .times:
            answered = left.multipliedReportingOverflow(by: right)

        case .dividedBy:
            return nil

        // A remainder is smaller in size than its divisor, so it always fits the int.
        // The overflow guard below is not its judge. The one divisor that trips
        // the hardware's division (`Int.min % -1`) still has the answer 0, so
        // it is answered directly.
        case .remainder:
            return right == -1 ? 0 : left % right
        }

        guard !answered.overflow else {
            throw ExecutionError(
                "\(procedure) of \(left) and \(right) overflows int"
            )
        }

        return answered.partialValue
    }

    private func real(_ left: Double, _ right: Double) -> Double {
        switch operation {
        case .plus:
            return left + right

        case .minus:
            return left - right

        case .times:
            return left * right

        case .dividedBy:
            return left / right

        // Truncating toward zero, the same as the whole answer, so both take
        // the dividend's sign.
        case .remainder:
            return left.truncatingRemainder(dividingBy: right)
        }
    }

    // The number a value carries, as the fraction path reads it: binary64's
    // own rounding, which every int is within reach of. Nil for what is not a
    // number.
    private func number(_ value: Value) -> Double? {
        switch value {
        case let .int(whole):
            return Double(whole)

        case let .double(real):
            return real

        default:
            return nil
        }
    }
}
