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
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        // Not a string is not a failure here. A path that asks a string procedure
        // of a number reads as absence, the same as a field never set.
        guard case let .string(text) = question[.of] else { return nil }

        return .string(text.uppercased())
    }

    // MARK: - Private
}
