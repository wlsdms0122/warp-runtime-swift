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
    // What this takes: the strings, and what goes between them. The
    // separator has a default because joining with nothing between is a
    // thing to want, and a defaulted parameter is what makes `parts.joined`
    // reachable from a path.
    enum Parameters: Int, ParameterSet {
        case of
        case value

        var name: Name {
            switch self {
            case .of:
                return "of"

            case .value:
                return "value"
            }
        }

        var declared: Parameter {
            switch self {
            case .of:
                return Parameter(type: .array(.string))

            case .value:
                return Parameter(type: .string, default: .string(""))
            }
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        // The `.array` case and not the elements projection, because this procedure
        // declares `array<string>` and bytes cross an `array<…>` slot whole
        // only where the element declaration leaves every byte alone. `string`
        // does not, so a bytes receiver is read out and refused element by
        // element at the boundary. Before here.
        guard case let .array(elements) = question.receiver else {
            throw ExecutionError(
                "joined asks \(question.receiver?.type.description ?? "nothing"), expected array"
            )
        }

        let given = question[.value]

        guard case let .string(separator) = given else {
            throw ExecutionError("joined asks a string separator, and \(given.type) arrived")
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
