//
//  FanoutOperand.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The pieces a fan-out is handed: closures under keys, or closures in order.
// Which of the two is each declaration's own, so the type is written where the
// procedure is declared.
enum FanoutOperand: Int, ParameterSet {
    case pieces

    // MARK: - Property
    var declared: Parameter {
        Parameter(name: "pieces")
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
