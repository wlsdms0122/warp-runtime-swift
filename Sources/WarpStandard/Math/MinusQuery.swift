//
//  MinusQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The difference, through the one arithmetic.
struct MinusQuery: Query {
    typealias Parameters = NumericPair

    // MARK: - Property
    private let arithmetic = Arithmetic(.minus)

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        try arithmetic.answer(question.receiver, question[.value])
    }

    // MARK: - Private
}
