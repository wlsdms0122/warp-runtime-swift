//
//  WriteParameters.swift
//  WarpConsole
//

import Foundation
import Warp

enum WriteParameters: Int, ParameterSet {
    case text

    // MARK: - Property
    var declared: Parameter { Parameter(name: "text", type: .string) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
