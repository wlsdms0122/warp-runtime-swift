//
//  MaxQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The larger of two of a kind, by the one order. A tie keeps the receiver.
struct MaxQuery: Query {
    typealias Parameters = ComparablePair

    // MARK: - Property
    private let ordering = Ordering("std.math.max")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        let operand = question[.value]
        let (order, receiver) = try ordering.of(question.receiver, and: operand)

        return order == .orderedAscending ? operand : receiver
    }

    // MARK: - Private
}
