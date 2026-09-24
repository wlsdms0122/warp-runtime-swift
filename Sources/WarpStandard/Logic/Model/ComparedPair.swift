//
//  ComparedPair.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The two values an equality procedure reads. Either side takes null:
// comparing against null is what asking whether a name holds anything is.
enum ComparedPair: Int, ParameterSet {
    case lhs
    case rhs

    // MARK: - Property
    var declared: Parameter {
        switch self {
        case .lhs:
            return Parameter(name: "lhs", type: .any)

        case .rhs:
            return Parameter(name: "rhs", type: .any)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
