//
//  ComparablePair.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The two values an ordering procedure reads. Both sides are the same member of the
// shared ground's `Comparable`, so what orders with what is decided by the
// membership rather than by each procedure.
enum ComparablePair: Int, ParameterSet {
    case lhs
    case rhs

    // MARK: - Property

    var declared: Parameter {
        switch self {
        case .lhs:
            return Parameter(name: "lhs", type: .parameter(name: "T", constraints: ["std.Comparable"]))

        case .rhs:
            return Parameter(name: "rhs", type: .parameter(name: "T", constraints: ["std.Comparable"]))
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
