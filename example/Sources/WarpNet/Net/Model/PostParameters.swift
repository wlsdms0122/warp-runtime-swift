//
//  PostParameters.swift
//  WarpNet
//

import Foundation
import Warp

enum PostParameters: Int, ParameterSet {
    case url
    case body
    case headers

    // MARK: - Property
    // Headers may be left out; the request reads null as none.
    var declared: Parameter {
        switch self {
        case .url:
            return Parameter(name: "url", type: .string)

        case .body:
            return Parameter(name: "body", type: .string)

        case .headers:
            return Parameter(name: "headers", type: .optional(.dictionary(key: .string, value: .string)))
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
