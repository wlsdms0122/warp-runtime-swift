//
//  NotQuery.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

// The opposite of a truth. It takes a value rather than a procedure because
// there is nothing to decline to ask. Negation reads its one side whatever the
// answer turns out to be.
struct NotQuery: Query {
    // What this takes: the truth, and nothing else.
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .bool) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        guard case let .bool(truth) = question.receiver else { return nil }

        return .bool(!truth)
    }

    // MARK: - Private
}
