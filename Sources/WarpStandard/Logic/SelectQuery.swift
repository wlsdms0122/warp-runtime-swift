//
//  SelectQuery.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

// The value one of two sides answers, chosen by a truth. Both sides are
// procedures rather than values, so the side not chosen goes unasked: a
// procedure receives its arguments already computed, and a chooser over values
// would have answered both before it could decline to.
//
// This is what `conditional` is not. A conditional chooses a way through a
// body, answers nothing and takes no name, so a body that answers without
// running has no construct to reach for and reaches for this instead.
struct SelectQuery: Query {
    // The places are the names in order, the way every declaration's are.
    enum Parameters: Int, ParameterSet {
        case `else`
        case of
        case then

        var name: Name {
            switch self {
            case .else:
                return "else"

            case .of:
                return "of"

            case .then:
                return "then"
            }
        }

        var declared: Parameter {
            switch self {
            case .of:
                return Parameter(type: .bool)

            case .then, .else:
                return Parameter(
                    type: .procedure(Signature(returns: .parameter(name: "Answer")), .pure)
                )
            }
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        guard case let .bool(taken) = question.receiver else { return nil }

        return try await question.call(question[taken ? .then : .else])
    }

    // MARK: - Private
}
