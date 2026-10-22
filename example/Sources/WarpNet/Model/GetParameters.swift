//
//  GetParameters.swift
//  WarpNet
//

import Foundation
import Warp

enum GetParameters: Int, ParameterSet {
    case url
    case headers

    // MARK: - Property
    // Headers may be left out; the request reads null as none.
    var declared: Parameter {
        switch self {
        case .url:
            return Parameter(name: "url", type: .string)

        case .headers:
            return Parameter(name: "headers", type: .nullable(.dictionary(key: .string, value: .string)))
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
