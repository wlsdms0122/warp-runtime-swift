//
//  FlooredQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The whole number at or below a number. Answers an int whatever it was sent,
// which is how a quotient becomes a whole number again: `dividedBy` always
// answers a double.
struct FlooredQuery: Query {
    typealias Parameters = NumberOperand

    // MARK: - Property
    private let integer = IntegerConversion("Standard.Math.floored")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .double(real) = question[.number] else {
            throw ExecutionError("Standard.Math.floored asks a fraction")
        }

        return .int(try integer.of(real, rounded: .down))
    }

    // MARK: - Private
}
