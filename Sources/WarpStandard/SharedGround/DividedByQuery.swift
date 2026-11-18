//
//  DividedByQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The quotient. Always a `Double`, even between two `Int`s.
struct DividedByQuery: Computation {
    typealias Parameters = NumericPair

    // MARK: - Property
    private let arithmetic: Arithmetic

    // MARK: - Initializer
    init(implementing procedure: String) {
        self.arithmetic = Arithmetic(.dividedBy, implementing: procedure)
    }

    // MARK: - Public
    func compute(_ arguments: Arguments<Self>) throws -> Value {
        try arithmetic.result(arguments[.lhs], arguments[.rhs])
    }

    // MARK: - Private
}
