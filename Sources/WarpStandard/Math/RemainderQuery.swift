//
//  RemainderQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// What is left of a division truncated toward zero, which takes the
// dividend's sign.
struct RemainderQuery: Query {
    typealias Parameters = NumericPair

    // MARK: - Property
    private let arithmetic = Arithmetic(.remainder)

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        try arithmetic.answer(question[.lhs], question[.rhs])
    }

    // MARK: - Private
}
