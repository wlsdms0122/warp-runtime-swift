//
//  SettingQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// The dictionary with one key bound to another value. It returns a new dictionary, so
// an author writes a changed dictionary without the language growing a way to
// write into one.
struct SettingQuery: Query {
    // What this takes: the dictionary, the key written, and what it holds.
    enum Parameters: Int, ParameterSet {
        case dictionary
        case key
        case value

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .dictionary:
                return Parameter(
                    name: "dictionary",
                    type: .dictionary(key: .parameter(name: "Key"), value: .parameter(name: "Value"))
                )

            case .key:
                return Parameter(name: "key", type: .parameter(name: "Key"))

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
        guard case let .dictionary(held) = question[.dictionary] else {
            throw ExecutionError("Standard.Collection.setting asks a Dictionary")
        }

        return .dictionary(held.writing(key: question[.key], with: question[.value]))
    }

    // MARK: - Private
}
