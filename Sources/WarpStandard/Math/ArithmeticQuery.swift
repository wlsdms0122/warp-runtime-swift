//
//  ArithmeticQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The numeric operations, as one implementation with the operation as its data.
// A name belongs to the declaration, so several declarations share one of these.
//
// Ints stay ints, so `2 plus 2` answers 4 rather than 4.0. Division is the
// exception, because a quotient is not generally whole. `remainder` is where a
// whole division's other half is read.
//
// `int` is the machine word, so a whole answer can fall off its edge. That is a
// fault of the program, not a condition of its data: an overflow and a divisor
// of zero stop the run the way an index past the end does, without the
// recoverable marker an `attempt` reads.
struct ArithmeticQuery: Query {
    enum Operation: Sendable {
        case plus
        case minus
        case times
        case dividedBy
        case remainder
    }

    // MARK: - Property
    private let operation: Operation

    // MARK: - Initializer
    public init(_ operation: Operation) {
        self.operation = operation
    }

    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        let operand = question["value"]

        guard let receiver = question.receiver, isNumber(receiver), isNumber(operand) else {
            throw ExecutionError(
                "arithmetic asks \(question.receiver?.type.description ?? "nothing") and"
                    + " \(operand.type), expected two numbers"
            )
        }

        // Zero by worth, whichever spelling carries it. The divisor is judged
        // before any conversion, so the check does not lean on what a fraction
        // can hold.
        guard !divides || !operand.matches(.int(0)) else {
            throw ExecutionError("\(operation) asks zero")
        }

        // A quotient is a fraction even between wholes, so `dividedBy` always
        // takes the fraction path.
        if
            case let .int(leftWhole) = receiver,
            case let .int(rightWhole) = operand,
            operation != .dividedBy
        {
            return .int(try whole(leftWhole, rightWhole))
        }

        let left = fraction(receiver)
        let right = fraction(operand)
        let answered = real(left, right)

        // The line the whole path holds with its edge. Infinity is a fraction
        // the arithmetic can reach and no document can carry, so answering it
        // would mint a value that exists only until someone writes it down.
        guard answered.isFinite else {
            throw ExecutionError(
                "\(operation) of \(left) and \(right) has no finite answer"
            )
        }

        return .double(answered)
    }

    // MARK: - Private
    // Whether a zero on the right has no answer. Both read a divisor, and both
    // are asked before the whole path so the check cannot be walked around.
    private var divides: Bool {
        operation == .dividedBy || operation == .remainder
    }

    private func whole(_ left: Int, _ right: Int) throws -> Int {
        let answered: (partialValue: Int, overflow: Bool)

        switch operation {
        case .plus:
            answered = left.addingReportingOverflow(right)

        case .minus:
            answered = left.subtractingReportingOverflow(right)

        case .times:
            answered = left.multipliedReportingOverflow(by: right)

        // A quotient is a fraction, so `dividedBy` never takes the whole path.
        // The caller's guard holds that line, and a call that slips it stops
        // here loudly rather than answering the other operation.
        case .dividedBy:
            preconditionFailure("a quotient is a fraction")

        // A remainder is smaller than its divisor, so it always fits the word.
        // The overflow guard below is not its judge. The one divisor that trips
        // the hardware's division (`Int.min % -1`) still has the answer 0, so
        // it is answered directly.
        case .remainder:
            return right == -1 ? 0 : left % right
        }

        guard !answered.overflow else {
            throw ExecutionError(
                "\(operation) of \(left) and \(right) overflows int"
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

        // Truncating toward zero, the same as the whole answer. A wrap written
        // over doubles reads the way the same wrap written over ints does.
        case .remainder:
            return left.truncatingRemainder(dividingBy: right)
        }
    }

    private func isNumber(_ value: Value?) -> Bool {
        switch value {
        case .int, .double:
            return true

        default:
            return false
        }
    }

    // The fraction path's reading of one side. Binary64's own rounding, which
    // every machine word is within reach of.
    private func fraction(_ value: Value?) -> Double {
        switch value {
        case let .int(whole):
            return Double(whole)

        case let .double(real):
            return real

        // The numeric guard in `evaluate` already refused everything else, so
        // reaching here is this file's own defect. The same line `whole` holds
        // for a quotient, not a failure a program could see.
        default:
            preconditionFailure("arithmetic reads a number it never admitted")
        }
    }
}

extension ArithmeticQuery.Operation: Equatable {
}
