//
//  UppercasedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The string in upper case.
struct UppercasedQuery: Query {
    typealias Parameters = StringOperand

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .string(text) = question[.text] else {
            throw ExecutionError("Standard.Text.uppercased asks a String")
        }

        return .string(text.uppercased())
    }

    // MARK: - Private
}
