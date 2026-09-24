//
//  ArrayAndElement.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// An array and one more element for it. The element is the array's own, so a
// procedure that puts it among the rest answers an array of the same kind.
enum ArrayAndElement: Int, ParameterSet {
    case of
    case value

    // MARK: - Property

    var declared: Parameter {
        switch self {
        case .of:
            return Parameter(name: "of", type: .array(.parameter(name: "Element")))

        case .value:
            return Parameter(name: "value", type: .parameter(name: "Element"))
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
