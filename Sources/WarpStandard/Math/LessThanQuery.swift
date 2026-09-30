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
    typealias Parameters = ComparablePair

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
