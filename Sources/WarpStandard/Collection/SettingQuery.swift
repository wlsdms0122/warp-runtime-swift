//
//  SettingQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// The record with one name bound to another value. It answers a new record, so
// an author writes a changed mapping without the language growing a way to
// write into one.
struct SettingQuery: Query {
    // What this takes: the mapping, the name written, and what it holds.
    enum Parameters: Int, ParameterSet {
        case dictionary
        case key
        case value

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .dictionary:
                return Parameter(name: "dictionary", type: .dictionary(.any))

            case .key:
                return Parameter(name: "key", type: .string)

            case .value:
                return Parameter(name: "value", type: .any)
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        guard
            let held = question[.dictionary].asDictionary,
            case let .string(key) = question[.key]
        else {
            throw ExecutionError("std.collection.setting asks a dictionary and a string")
        }

        let field: Name

        do {
            field = try Name(key)
        } catch let refusal as NameRefused {
            throw ExecutionError(
                "std.collection.setting asks a key that is a name, and \(refusal.message)"
            )
        }

        // The names are data from here on: what was written was held to no
        // declaration, so the answer is a dictionary whatever the collection was.
        return .dictionary(held.writing(field, with: question[.value]))
    }

    // MARK: - Private
}
