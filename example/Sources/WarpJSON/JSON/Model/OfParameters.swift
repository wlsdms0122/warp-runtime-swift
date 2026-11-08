//
//  OfParameters.swift
//  WarpJSON
//

import Foundation
import Warp

enum OfParameters: Int, ParameterSet {
    case of

    // MARK: - Property
    var declared: Parameter { Parameter(name: "of", type: .any) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
