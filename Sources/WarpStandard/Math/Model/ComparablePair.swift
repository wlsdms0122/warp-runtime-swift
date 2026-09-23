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
    case of
    case value

    // MARK: - Property

    var declared: Parameter {
        switch self {
        case .of:
            return Parameter(name: "of", type: .parameter(name: "T", constraints: ["std.Comparable"]))

        case .value:
            return Parameter(name: "value", type: .parameter(name: "T", constraints: ["std.Comparable"]))
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
