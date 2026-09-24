//
//  DividedByQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The quotient. Always a fraction, even between wholes, which is why
// `remainder` exists to read a whole division's other half.
struct DividedByQuery: Query {
    typealias Parameters = NumericPair

    // MARK: - Property
    private let arithmetic = Arithmetic(.dividedBy)

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try arithmetic.answer(question[.of], question[.value])
    }

    // MARK: - Private
}
