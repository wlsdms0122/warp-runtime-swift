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

        var declared: Parameter {
            switch self {
            case .strings:
                return Parameter(name: "strings", type: .array(.string))

            case .separator:
                return Parameter(name: "separator", type: .string)
            }
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        // The `.array` case and not the elements projection, because this procedure
        // declares `array<string>` and bytes cross an `array<…>` slot whole
        // only where the element declaration leaves every byte alone. `string`
        // does not, so bytes are read out and refused element by
        // element at the boundary. Before here.
        guard case let .array(elements) = question[.strings] else {
            throw ExecutionError(
                "joined asks \(question[.strings].type), expected array"
            )
        }

        guard case let .string(separator) = question[.separator] else {
            throw ExecutionError("joined asks a string separator, and \(question[.separator].type) arrived")
        }

        let written = try elements.map { element -> String in
            guard case let .string(text) = element else {
                throw ExecutionError("joined asks an array holding \(element.type)")
            }

            return text
        }

        return .string(written.joined(separator: separator))
    }

    // MARK: - Private
}
