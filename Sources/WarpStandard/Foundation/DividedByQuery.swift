//
//  DividedByQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The quotient. Always a fraction, even between wholes.
struct DividedByQuery: Query {
    typealias Parameters = NumericPair

    // MARK: - Property
    private let arithmetic: Arithmetic

    // MARK: - Initializer
    init(answering procedure: String) {
        self.arithmetic = Arithmetic(.dividedBy, answering: procedure)
    }

    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        try arithmetic.answer(question[.lhs], question[.rhs])
    }

    // MARK: - Private
}
