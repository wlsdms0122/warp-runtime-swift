//
//  MinQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The smaller of two of a kind. The picking half of the one order,
// answering with one of the pair instead of a bool: no arithmetic runs, so
// the value comes back as it arrived, and a tie keeps the receiver.
struct MinQuery: Query {
    typealias Parameters = ComparablePair

    // MARK: - Property
    private let ordering = Ordering("std.math.min")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        let operand = question[.value]
        let (order, receiver) = try ordering.of(question.receiver, and: operand)

        return order == .orderedDescending ? operand : receiver
    }

    // MARK: - Private
}
