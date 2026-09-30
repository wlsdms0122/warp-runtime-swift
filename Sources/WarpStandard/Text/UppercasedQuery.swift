//
//  UppercasedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The text in upper case.
struct UppercasedQuery: Query {
    typealias Parameters = StringOperand

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .string(text) = question[.text] else {
            throw ExecutionError("std.text.uppercased asks a string")
        }

        return .string(text.uppercased())
    }

    // MARK: - Private
}
