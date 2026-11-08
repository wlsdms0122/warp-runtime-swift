//
//  PathParameters.swift
//  WarpFile
//

import Foundation
import Warp

enum PathParameters: Int, ParameterSet {
    case path

    // MARK: - Property
    var declared: Parameter { Parameter(name: "path", type: .string) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
