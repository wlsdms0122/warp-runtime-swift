//
//  KeysQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// The names a record holds, in order. Declared fields are read by name; this
// reads names that are data, and is how a program walks them without knowing
// what they are called.
struct KeysQuery: Query {
    // What this takes: the mapping, and nothing else.
    enum Parameters: Int, ParameterSet {
        case dictionary
        var declared: Parameter { Parameter(name: "dictionary", type: .dictionary(.any)) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        guard let held = question[.dictionary].asDictionary else { return nil }

        // In name order, the order both spellings hold: a walk that answered a
        // different order each run would make a program that reads it depend on
        // nothing an author wrote.
        return .array(held.names.map { name in .string(name.spelling) })
    }

    // MARK: - Private
}
