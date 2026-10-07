//
//  RoundedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The nearest whole number. Answers an int whatever it was sent, the same as
// `floored`.
struct RoundedQuery: Query {
    typealias Parameters = NumberOperand

    // MARK: - Property
    private let integer = IntegerConversion("Standard.Math.rounded")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        switch question[.number] {
        case let .int(number):
            return .int(number)

        case let .double(real):
            return .int(try integer.of(real, rounded: .toNearestOrAwayFromZero))

        default:
            throw ExecutionError("Standard.Math.rounded asks a number")
        }
    }

    // MARK: - Private
}
