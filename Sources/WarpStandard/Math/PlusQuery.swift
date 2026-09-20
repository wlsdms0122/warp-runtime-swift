//
//  PlusQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The sum. Whole where both sides are, through the one arithmetic.
struct PlusQuery: Query {
    typealias Parameters = NumericPair

    // MARK: - Property
    private let arithmetic = Arithmetic(.plus)

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try arithmetic.answer(question.receiver, question[.value])
    }

    // MARK: - Private
}
