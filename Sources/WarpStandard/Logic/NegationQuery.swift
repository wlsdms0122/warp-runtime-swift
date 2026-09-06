//
//  NegationQuery.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

// The opposite of a truth. It takes a value rather than a procedure because
// there is nothing to decline to ask. Negation reads its one side whatever the
// answer turns out to be.
struct NegationQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        guard case let .bool(truth) = question.receiver else { return nil }

        return .bool(!truth)
    }

    // MARK: - Private
}
