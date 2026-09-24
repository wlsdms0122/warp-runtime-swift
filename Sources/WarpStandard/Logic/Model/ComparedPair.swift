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
    case of
    case value

    // MARK: - Property
    var declared: Parameter {
        switch self {
        case .of:
            return Parameter(name: "of", type: .any)

        case .value:
            return Parameter(name: "value", type: .any)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
