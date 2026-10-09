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
    // the standard vocabulary's page says the language cannot express.
    // `trimmed` is one: whether a character is whitespace is a question about
    // the code points inside it, and `characters` answers characters.
    static let builtinProcedures: Set<Name> = [
        "Standard.Logic.equal",

        "Int.plus", "Int.minus", "Int.times", "Int.dividedBy", "Int.remainder", "Int.lessThan",
        "Double.plus", "Double.minus", "Double.times", "Double.dividedBy", "Double.remainder", "Double.lessThan",
        "String.lessThan", "Standard.Math.floored", "Standard.Math.rounded",

        "Standard.Text.text", "Standard.Text.joined", "Standard.Text.characters", "Standard.Text.uppercased",
        "Standard.Text.lowercased", "Standard.Text.encoded", "Standard.Text.decoded", "Standard.Text.trimmed",

        "Array.count", "Dictionary.count", "String.count", "Standard.Collection.appending",
        "Standard.Collection.gathering", "Standard.Collection.keys", "Standard.Collection.setting",

        "Standard.Control.abort",

        "Standard.Concurrent.all", "Standard.Concurrent.allKeyed", "Standard.Concurrent.first",
        "Standard.Concurrent.firstKeyed"
    ]

    // The procedures that are written in Warp from the builtin ones. Named by
    // what is left rather than listed, so a procedure added to a bundle lands
    // here unless it is put in the set above, and never in neither.
    static var derived: Set<Name> {
        Set(standard.flatMap(\.procedures.keys)).subtracting(builtinProcedures)
    }
}
