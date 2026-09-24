//
//  NumericPair.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The two numbers an arithmetic procedure reads. One type because the two sides of
// every operation are declared alike: both are the same member of the shared
// ground's `Numeric`, so a whole answers a whole and a fraction a fraction.
enum NumericPair: Int, ParameterSet {
    case lhs
    case rhs

    // MARK: - Property

    var declared: Parameter {
        switch self {
        case .lhs:
            return Parameter(name: "lhs", type: .parameter(name: "N", constraints: ["std.Numeric"]))

        case .rhs:
            return Parameter(name: "rhs", type: .parameter(name: "N", constraints: ["std.Numeric"]))
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
