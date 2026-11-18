//
//  PutParameters.swift
//  warpx
//

import Foundation
import Warp

enum PutParameters: Int, ParameterSet {
    case key
    case value

    // MARK: - Property
    var declared: Parameter {
        switch self {
        case .key:
            return Parameter(name: "key", type: .string)

        case .value:
            return Parameter(name: "value", type: .any)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
