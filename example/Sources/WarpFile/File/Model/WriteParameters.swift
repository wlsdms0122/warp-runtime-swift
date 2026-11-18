//
//  WriteParameters.swift
//  WarpFile
//

import Foundation
import Warp

enum WriteParameters: Int, ParameterSet {
    case path
    case text

    // MARK: - Property
    var declared: Parameter {
        switch self {
        case .path:
            return Parameter(name: "path", type: .string)

        case .text:
            return Parameter(name: "text", type: .string)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
