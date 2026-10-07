//
//  NumericPair.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The two numbers an arithmetic procedure reads. One type because the two sides of
// every operation are declared alike: both are the one type answering
// `Standard.Numeric`, so a whole answers a whole and a fraction a fraction.
enum NumericPair: Int, ParameterSet {
    case lhs
    case rhs

    // MARK: - Property
    // The type is each declaration's own: one query answers for every type
    // a numeric procedure is declared for.
    var declared: Parameter {
        switch self {
        case .lhs:
            return Parameter(name: "lhs")

        case .rhs:
            return Parameter(name: "rhs")
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
