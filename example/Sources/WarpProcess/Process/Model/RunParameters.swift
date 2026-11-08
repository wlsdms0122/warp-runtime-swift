//
//  RunParameters.swift
//  WarpProcess
//

import Foundation
import Warp

enum RunParameters: Int, ParameterSet {
    case command

    // MARK: - Property
    var declared: Parameter { Parameter(name: "command", type: .string) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
