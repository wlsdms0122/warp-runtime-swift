//
//  OneName.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp
import WarpSyntax
import WarpStandard

// The names a procedure a case asks for may declare, in the order a
// declaration's names stand in. A case cannot invent a place in someone else's
// runner, so the places are fixed here and the spec says which they are.
enum OneName: Int, ParameterSet {
    case first

    // MARK: - Property
    var declared: Parameter { Parameter(name: "first", type: .any) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
