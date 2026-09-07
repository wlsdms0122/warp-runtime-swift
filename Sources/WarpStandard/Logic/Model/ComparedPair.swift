//
//  ComparedPair.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The two values an equality word reads. Nothing is required on either side:
// comparing against null is what asking whether a name holds anything is, and a
// required parameter cannot be given null.
enum ComparedPair: Int, ParameterSet {
    case of
    case value

    // MARK: - Property
    var name: Name {
        switch self {
        case .of:
            return "of"

        case .value:
            return "value"
        }
    }

    var declared: Parameter { Parameter(type: .any, default: .null) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
