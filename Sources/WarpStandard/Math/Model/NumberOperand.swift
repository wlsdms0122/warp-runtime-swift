//
//  NumberOperand.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The one number a rounding procedure reads, a member of the shared ground's
// `Numeric`. It takes nothing else.
enum NumberOperand: Int, ParameterSet {
    case of

    // MARK: - Property
    var declared: Parameter { Parameter(name: "of", type: .parameter(name: "N", constraints: ["std.Numeric"])) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
