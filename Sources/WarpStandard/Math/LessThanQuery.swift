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
    // What this takes: two values of one member of `Standard.Comparable`.
    enum Parameters: Int, ParameterSet {
        case lhs
        case rhs

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .lhs:
                return Parameter(
                    name: "lhs",
                    type: .parameter(name: "T", constraints: ["Standard.Comparable"])
                )

            case .rhs:
                return Parameter(
                    name: "rhs",
                    type: .parameter(name: "T", constraints: ["Standard.Comparable"])
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
    func evaluate(_ question: Question<Self>) async throws -> Value {
        let lhs = question[.lhs]
        let rhs = question[.rhs]

        // A pair with no order is refused rather than answered false: false
        // claims the opposite comparison would say something, and it would not.
        guard let order = Value.order(lhs, rhs) else {
            throw ExecutionError(
                "Standard.Math.lessThan asks \(lhs.type) and \(rhs.type), which have no order."
                    + " It takes two numbers or two strings"
            )
        }

        return .bool(order == .orderedAscending)
    }

    // MARK: - Private
}
