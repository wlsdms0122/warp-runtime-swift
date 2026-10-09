//
//  Module+Builtin.swift
//  WarpStandard
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Warp

public extension Module {
    // The procedures an implementation writes in its own language, the ones
    // the standard vocabulary's page says the language cannot express: what
    // the bundles' builtin halves declare.
    static let builtinProcedures: Set<Name> = Set(standard.filter(\.builtin).flatMap(\.procedures.keys))

    // The procedures that are written in Warp from the builtin ones: what
    // the bundles' written halves declare.
    static let derived: Set<Name> = Set(standard.filter { module in !module.builtin }.flatMap(\.procedures.keys))
}
