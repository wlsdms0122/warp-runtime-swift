//
//  RoundedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The integer nearest a floating-point number, as an `Int`, the same as
// `floored`.
struct RoundedQuery: Query {
    typealias Parameters = NumberOperand

    // MARK: - Property
    private let integer = IntegerConversion("Standard.Math.rounded")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .double(real) = question[.number] else {
            throw ExecutionError("Standard.Math.rounded asks a Double")
        }

        return .int(try integer.of(real, rounded: .toNearestOrAwayFromZero))
    }

    // MARK: - Private
}
