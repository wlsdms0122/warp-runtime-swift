//
//  JoinedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// Strings written one after another, with a separator between.
struct JoinedQuery: Query {
    // What this takes: the strings, and what goes between them.
    enum Parameters: Int, ParameterSet {
        case strings
        case separator

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .strings:
                return Parameter(name: "strings", type: .array(.string))

            case .separator:
                return Parameter(name: "separator", type: .string)
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
            case let .array(elements) = question[.strings],
            case let .string(separator) = question[.separator]
        else {
            throw ExecutionError("std.text.joined asks an array and a string")
        }

        let written = try elements.map { element -> String in
            guard case let .string(text) = element else {
                throw ExecutionError("std.text.joined asks an array of strings")
            }

            return text
        }

        return .string(written.joined(separator: separator))
    }

    // MARK: - Private
}
