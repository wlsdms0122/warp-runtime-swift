//
//  ParseQuery.swift
//  WarpJSON
//

import Foundation
import Warp

struct ParseQuery: Query {
    typealias Parameters = TextParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .string(text) = question[.of] else {
            throw ExecutionError("JSON.parse asks a string")
        }

        return try JSON().value(from: text)
    }

    // MARK: - Private
}
