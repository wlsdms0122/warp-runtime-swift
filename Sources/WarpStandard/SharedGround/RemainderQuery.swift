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
struct RemainderQuery: Computation {
    typealias Parameters = NumericPair

    // MARK: - Property
    private let arithmetic: Arithmetic

    // MARK: - Initializer
    init(implementing procedure: String) {
        self.arithmetic = Arithmetic(.remainder, implementing: procedure)
    }

    // MARK: - Public
    func compute(_ arguments: Arguments<Self>) throws -> Value {
        try arithmetic.result(arguments[.lhs], arguments[.rhs])
    }

    // MARK: - Private
}
