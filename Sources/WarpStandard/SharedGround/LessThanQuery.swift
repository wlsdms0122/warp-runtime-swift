//
//  LessThanQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// Whether one orders before the other.
struct LessThanQuery: Query {
    // What this takes: two values of the one type a declaration satisfies
    // `Standard.Comparable` for. The type is each declaration's own, since one
    // query satisfies it for each type the shared ground claims it for.
    enum Parameters: Int, ParameterSet {
        case lhs
        case rhs

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .lhs:
                return Parameter(name: "lhs")

            case .rhs:
                return Parameter(name: "rhs")
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The declared spelling, which a refusal names.
    private let procedure: String

    // MARK: - Initializer
    init(implementing procedure: String) {
        self.procedure = procedure
    }

    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        let lhs = question[.lhs]
        let rhs = question[.rhs]

        // A pair with no order is refused rather than returning false: false
        // claims the opposite comparison would say something, and it would not.
        guard let less = ordered(lhs, rhs) else {
            throw ExecutionError(
                "\(procedure) asks \(lhs.nominal) and \(rhs.nominal), which have no order"
            )
        }

        return .bool(less)
    }

    // MARK: - Private
    // Whether one orders before the other, for the kinds that order: integers,
    // floating-point numbers and strings. Nil is a pair with no order: two of
    // different kinds, or a kind that does not order.
    private func ordered(_ lhs: Value, _ rhs: Value) -> Bool? {
        switch (lhs, rhs) {
        case let (.int(first), .int(second)):
            return first < second

        case let (.double(first), .double(second)):
            return first < second

        case let (.string(first), .string(second)):
            return first < second

        default:
            return nil
        }
    }
}
