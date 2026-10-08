//
//  NumberOperand.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The one number a rounding procedure reads, a fraction. It takes nothing else.
enum NumberOperand: Int, ParameterSet {
    case number

    // MARK: - Property
    var declared: Parameter {
        Parameter(name: "number", type: .double)
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
