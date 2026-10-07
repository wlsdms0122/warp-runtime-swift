//
//  FanoutOperand.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The pieces a fan-out is handed: closures under keys, or closures in order.
// Two types and no third, which is what the membership says and what `any`
// could not.
enum FanoutOperand: Int, ParameterSet {
    case pieces

    // MARK: - Property
    var declared: Parameter {
        Parameter(name: "pieces", type: .named("Standard.Concurrent.Pieces"))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
