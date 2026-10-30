//
//  FlooredQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The integer at or below a floating-point number, as an `Int`, which is how
// a quotient becomes an integer again: `dividedBy` always returns a `Double`.
struct FlooredQuery: Query {
    typealias Parameters = NumberOperand

    // MARK: - Property
    private let integer = IntegerConversion("Standard.Math.floored")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .double(real) = question[.number] else {
            throw ExecutionError("Standard.Math.floored asks a Double")
        }

        return .int(try integer.of(real, rounded: .down))
    }

    // MARK: - Private
}
