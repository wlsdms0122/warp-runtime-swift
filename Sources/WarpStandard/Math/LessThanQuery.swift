//
//  LessThanQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// Whether this orders before another. `not` is a language operator, so
// "at least" is `not lessThan` and there are two comparisons rather than
// four.
struct LessThanQuery: Query {
    // What this takes: two values of one member of `std.Comparable`.
    enum Parameters: Int, ParameterSet {
        case lhs
        case rhs

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .lhs:
                return Parameter(
                    name: "lhs",
                    type: .parameter(name: "T", constraints: ["std.Comparable"])
                )

            case .rhs:
                return Parameter(
                    name: "rhs",
                    type: .parameter(name: "T", constraints: ["std.Comparable"])
                )
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        let lhs = question[.lhs]
        let rhs = question[.rhs]

        // A pair with no order is refused rather than answered false: false
        // claims the opposite comparison would say something, and it would not.
        guard let order = Value.order(lhs, rhs) else {
            throw ExecutionError(
                "std.math.lessThan asks \(lhs.type) and \(rhs.type), which have no order."
                    + " It takes two numbers or two strings"
            )
        }

        return .bool(order == .orderedAscending)
    }

    // MARK: - Private
}
