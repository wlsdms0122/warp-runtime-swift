//
//  ValuesQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// What a record holds, by its names in order.
struct ValuesQuery: Query {
    // What this takes: the mapping, and nothing else.
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .dictionary(.parameter(name: "Entry"))) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        guard let held = question.receiver?.asDictionary else { return nil }

        return .array(held.values)
    }

    // MARK: - Private
}
