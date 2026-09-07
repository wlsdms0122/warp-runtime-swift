//
//  ComparablePair.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The two values an ordering word reads. Both sides are the same member of the
// shared ground's `Comparable`, so what orders with what is decided by the
// membership rather than by each word.
enum ComparablePair: Int, ParameterSet {
    case of
    case value

    // MARK: - Property
    var name: Name {
        switch self {
        case .of:
            return "of"

        case .value:
            return "value"
        }
    }

    var declared: Parameter {
        Parameter(type: .parameter(name: "T", constraint: "std.Comparable"))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
