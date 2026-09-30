//
//  TwoNames.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/27/26.
//

import Foundation
import Warp
import WarpSyntax
import WarpStandard

enum TwoNames: Int, ParameterSet {
    case first
    case second

    // MARK: - Property
    var declared: Parameter {
        switch self {
        case .first:
            return Parameter(name: "first", type: .any)

        case .second:
            return Parameter(name: "second", type: .any)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
