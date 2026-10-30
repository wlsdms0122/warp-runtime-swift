//
//  TextParameters.swift
//  WarpJSON
//

import Foundation
import Warp

enum TextParameters: Int, ParameterSet {
    case of

    // MARK: - Property
    var declared: Parameter { Parameter(name: "of", type: .string) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
