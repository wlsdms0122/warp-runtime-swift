//
//  MinusQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The difference, through the one arithmetic.
struct MinusQuery: Computation {
    typealias Parameters = NumericPair

    // MARK: - Property
    private let arithmetic: Arithmetic

    // MARK: - Initializer
    init(implementing procedure: String) {
        self.arithmetic = Arithmetic(.minus, implementing: procedure)
    }

    // MARK: - Public
    func compute(_ arguments: Arguments<Self>) throws -> Value {
        try arithmetic.result(arguments[.lhs], arguments[.rhs])
    }

    // MARK: - Private
}
