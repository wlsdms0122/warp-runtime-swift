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
    private let ordering = Ordering("std.math.lessThan")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        let (order, _) = try ordering.of(question[.lhs], and: question[.rhs])

        return .bool(order == .orderedAscending)
    }

    // MARK: - Private
}
