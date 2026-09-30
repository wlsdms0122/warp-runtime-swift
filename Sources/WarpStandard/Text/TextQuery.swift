//
//  TextQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

// How any value reads as text, in the type's own spelling. It takes every
// value, because it is what interpolation is made of: interpolating a number
// is the ordinary case, and null spells as `null`, the way it does inside a
// container.
struct TextQuery: Query {
    // What this takes: the value spelled, and nothing else.
    enum Parameters: Int, ParameterSet {
        case value

        // MARK: - Property
        var declared: Parameter { Parameter(name: "value", type: .any) }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        .string(Rendering(question[.value]).text())
    }

    // MARK: - Private
}
