//
//  WaitParameters.swift
//  WarpTime
//

import Foundation
import Warp

enum WaitParameters: Int, ParameterSet {
    case milliseconds

    // MARK: - Property
    var declared: Parameter { Parameter(name: "milliseconds", type: .int) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
