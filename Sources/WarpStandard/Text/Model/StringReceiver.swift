//
//  StringReceiver.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The one string a transformation reads. It takes nothing else, which is what
// makes `name.uppercased` reachable from a path.
enum StringReceiver: Int, ParameterSet {
    case of

    // MARK: - Property
    var declared: Parameter { Parameter(name: "of", type: .string) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
