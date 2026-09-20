//
//  NumberReceiver.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The one number a rounding procedure reads, a member of the shared ground's
// `Numeric`. It takes nothing beyond its receiver, which is what makes
// `quotient.floored` reachable from a path.
enum NumberReceiver: Int, ParameterSet {
    case of

    // MARK: - Property
    var name: Name { "of" }

    var declared: Parameter { Parameter(type: .parameter(name: "N", constraints: ["std.Numeric"])) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
