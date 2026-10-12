//
//  KeysQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// The keys a map holds, in its key order. A declared struct's fields are read
// by name; a map's keys are data, and this is how a program walks them
// without knowing what they are.
struct KeysQuery: Query {
    // What this takes: the map, and nothing else.
    enum Parameters: Int, ParameterSet {
        case dictionary

        // MARK: - Property
        var declared: Parameter {
            Parameter(name: "dictionary", type: .dictionary(key: .parameter(name: "Key"), value: .any))
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .dictionary(held) = question[.dictionary] else {
            throw ExecutionError("Standard.Collection.keys asks a Dictionary")
        }

        // In the key order the map holds them in: a walk that answered a
        // different order each run would make a program that reads it depend on
        // nothing an author wrote.
        return .array(held.keys)
    }

    // MARK: - Private
}
