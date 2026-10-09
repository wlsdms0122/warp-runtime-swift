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

// The place a procedure a case asks for reads its one argument at, `first`.
enum OneName: Int, ParameterSet {
    case first

    // MARK: - Property
    var declared: Parameter { Parameter(name: "first", type: .any) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
