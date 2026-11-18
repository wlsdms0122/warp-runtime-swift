//
//  LogParameters.swift
//  warpx
//

import Foundation
import Warp

enum LogParameters: Int, ParameterSet {
    case of

    // MARK: - Property
    var declared: Parameter { Parameter(name: "of", type: .any) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
