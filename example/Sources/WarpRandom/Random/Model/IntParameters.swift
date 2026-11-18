//
//  IntParameters.swift
//  WarpRandom
//

import Foundation
import Warp

enum IntParameters: Int, ParameterSet {
    case under

    // MARK: - Property
    var declared: Parameter { Parameter(name: "under", type: .int) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
