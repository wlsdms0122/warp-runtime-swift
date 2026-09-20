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
        case key
        case of
        case value

        var name: Name {
            switch self {
            case .key:
                return "key"

            case .of:
                return "of"

            case .value:
                return "value"
            }
        }

        var declared: Parameter {
            switch self {
            case .key:
                return Parameter(type: .string)

            case .of:
                return Parameter(type: .dictionary(.any))

            case .value:
                return Parameter(type: .any)
            }
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        guard let held = question.receiver?.asDictionary else { return nil }

        guard case let .string(key) = question[.key] else {
            throw ExecutionError("setting asks a string key")
        }

        let field: Name

        do {
            field = try Name(key)
        } catch let refusal as NameRefused {
            throw ExecutionError("setting asks a key that is a name, and \(refusal.message)")
        }

        // The names are data from here on: what was written was held to no
        // declaration, so the answer is a dictionary whatever the receiver was.
        return .dictionary(held.writing(field, with: question[.value]))
    }

    // MARK: - Private
}
