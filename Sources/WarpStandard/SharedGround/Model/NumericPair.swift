//
//  NumericPair.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The two numbers an arithmetic procedure reads. One type because the two sides of
// every operation are declared alike: both are the one type a declaration
// satisfies `Standard.Numeric` for, so two `Int`s return an `Int` and two
// `Double`s a `Double`.
enum NumericPair: Int, ParameterSet {
    case lhs
    case rhs

    // MARK: - Property
    // The type is each declaration's own: one query satisfies it for each type
    // the shared ground claims `Standard.Numeric` for.
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
