//
//  StringPair.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// A string and the string a procedure reads it against: a prefix, a pattern, a
// separator.
enum StringPair: Int, ParameterSet {
    case of
    case value

    // MARK: - Property
    var name: Name {
        switch self {
        case .of:
            return "of"

        case .value:
            return "value"
        }
    }

    var declared: Parameter { Parameter(type: .string) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
