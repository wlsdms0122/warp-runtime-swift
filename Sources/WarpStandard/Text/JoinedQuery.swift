//
//  JoinedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// Strings written one after another, with a separator between. The separator
// has a default because joining with nothing between is a thing to want, and
// declaring the default is what makes `parts.joined` reachable from a path.
public struct JoinedQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        // The `.array` case and not the elements projection, because this word
        // declares `array<string>` and bytes cross an `array<…>` slot whole
        // only where the element declaration leaves every byte alone. `string`
        // does not, so a bytes receiver is read out and refused element by
        // element at the boundary — before here.
        guard case let .array(elements) = question.receiver else {
            throw ExecutionError(
                "joined asks \(question.receiver?.type.description ?? "nothing"), expected array"
            )
        }

        let given = question["value"]

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
