//
//  RemainderQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// What is left of a whole division. The half `dividedBy` cannot answer,
// since a quotient is a fraction.
struct RemainderQuery: Query {
    typealias Parameters = NumericPair

    // MARK: - Property
    private let arithmetic = Arithmetic(.remainder)

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        try arithmetic.answer(question.receiver, question[.value])
    }

    // MARK: - Private
}
