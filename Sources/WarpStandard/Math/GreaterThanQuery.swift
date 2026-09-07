//
//  GreaterThanQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// Whether this orders after another.
struct GreaterThanQuery: Query {
    typealias Parameters = ComparablePair

    // MARK: - Property
    private let ordering = Ordering("std.math.greaterThan")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        let (order, _) = try ordering.of(question.receiver, and: question[.value])

        return .bool(order == .orderedDescending)
    }

    // MARK: - Private
}
