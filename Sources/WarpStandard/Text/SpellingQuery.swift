//
//  SpellingQuery.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

// How any value reads as text. It keeps the opposite contract to the words
// that transform a string: those answer absence for anything else, this takes
// every shape and refuses only nothing.
//
// It is what interpolation is made of, which is why it takes more than a
// string. Interpolating a number is the ordinary case. Nothing renders null,
// because completing a sentence with "" would be the language writing what the
// author did not.
struct SpellingQuery: Query {
    // What this takes: the value spelled, and nothing else.
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .any) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        let value = question.receiver ?? .null

        guard value != .null else {
            throw ExecutionError("text asks nothing, and nothing has no spelling")
        }

        return .string(Rendering(value).text())
    }

    // MARK: - Private
}
