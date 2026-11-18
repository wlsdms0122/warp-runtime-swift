//
//  GetParameters.swift
//  warpx
//

import Foundation
import Warp

enum GetParameters: Int, ParameterSet {
    case key

    // MARK: - Property
    var declared: Parameter { Parameter(name: "key", type: .string) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
