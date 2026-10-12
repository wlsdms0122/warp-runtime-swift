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
    private let arithmetic: Arithmetic

    // MARK: - Initializer
    init(answering procedure: String) {
        self.arithmetic = Arithmetic(.minus, answering: procedure)
    }

    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        try arithmetic.answer(question[.lhs], question[.rhs])
    }

    // MARK: - Private
}
