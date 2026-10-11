//
//  SettingQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// The map with one name bound to another value. It answers a new map, so
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
                return Parameter(name: "dictionary", type: .dictionary(key: .string, value: .parameter(name: "Value")))

            case .key:
                return Parameter(name: "key", type: .string)

            case .value:
                return Parameter(name: "value", type: .parameter(name: "Value"))
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
        guard
            case let .dictionary(held) = question[.dictionary],
            case let .string(key) = question[.key]
        else {
            throw ExecutionError("Standard.Collection.setting asks a Dictionary and a String")
        }

        let field: Name

        do {
            field = try Name(key)
        } catch let refusal as NameRefused {
            throw ExecutionError(
                "Standard.Collection.setting asks a key that is a name, and \(refusal.message)"
            )
        }

        return .dictionary(held.writing(field, with: question[.value]))
    }

    // MARK: - Private
}
