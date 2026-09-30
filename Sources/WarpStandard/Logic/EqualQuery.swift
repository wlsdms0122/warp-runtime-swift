//
//  EqualQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// Whether two values are the same. Numbers compare across their
// representations, so `1` and `1.0` are one value asked about twice.
struct EqualQuery: Query {
    // What this takes: the two values compared. Either side takes null, since
    // comparing against null is what asking whether a name holds anything is.
    enum Parameters: Int, ParameterSet {
        case lhs
        case rhs

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .lhs:
                return Parameter(name: "lhs", type: .any)

            case .rhs:
                return Parameter(name: "rhs", type: .any)
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
        .bool(question[.lhs].matches(question[.rhs]))
    }

    // MARK: - Private
}
