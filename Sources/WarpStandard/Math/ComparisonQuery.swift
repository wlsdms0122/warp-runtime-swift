//
//  ComparisonQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// Ordering — the words that ask it and the words that pick by it. One type,
// because there is one order: whether a pair may be ordered and how is decided
// here and nowhere else, so `min` cannot drift from what `lessThan` reads.
// Two comparison declarations rather than four: `not` is a language operator,
// so "at least" is `not lessThan`.
public struct ComparisonQuery: Query {
    public enum Ordering: Sendable {
        case lessThan
        case greaterThan
        // The picking half: the same order, answering with one of the pair
        // instead of a bool. No arithmetic runs, so nothing converts — the
        // value comes back as it arrived, and a tie keeps the receiver.
        case min
        case max
    }

    // MARK: - Property
    private let ordering: Ordering

    // MARK: - Initializer
    public init(_ ordering: Ordering) {
        self.ordering = ordering
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        let operand = question["value"]

        // Its own refusal for an absent left side — these words order, so
        // arithmetic's "expected two numbers" would name a domain they do
        // not have.
        guard let receiver = question.receiver else {
            throw ExecutionError(
                "\(ordering) asks two of a kind, and nothing arrived to order"
            )
        }

        // One order for everything that has one — numbers by worth, exactly
        // at every size, and strings lexicographically. A pair with no order
        // is refused rather than answered false or picked from: false claims
        // the opposite comparison would say something, and it would not.
        guard let order = Value.order(receiver, operand) else {
            throw ExecutionError(
                "\(ordering) asks \(receiver.type) and"
                    + " \(operand.type), which have no order —"
                    + " it takes two numbers or two strings"
            )
        }

        switch ordering {
        case .lessThan:
            return .bool(order == .orderedAscending)

        case .greaterThan:
            return .bool(order == .orderedDescending)

        case .min:
            return order == .orderedDescending ? operand : receiver

        case .max:
            return order == .orderedAscending ? operand : receiver
        }
    }

    // MARK: - Private
}
