//
//  Module+Builtin.swift
//  WarpStandard
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Warp

public extension Module {
    // The procedures an implementation writes in its own language. What makes
    // one of these builtin is that the language cannot express it: arithmetic
    // and ordering are the machine's, case mapping and encoding carry
    // Unicode's tables with them, running at once is the host's scheduler, and
    // `appending` is the only way an array grows and `gathering` the only way
    // an answer keeps the spelling its collection arrived in.
    //
    // `trimmed` names the set it removes and still stands here: whether a
    // character is whitespace is a question about the code points inside it,
    // and `characters` answers characters.
    static let builtinProcedures: Set<Name> = [
        "Standard.Logic.equal",

        "Standard.Math.plus", "Standard.Math.minus", "Standard.Math.times", "Standard.Math.dividedBy",
        "Standard.Math.remainder", "Standard.Math.lessThan", "Standard.Math.floored", "Standard.Math.rounded",

        "Standard.Text.text", "Standard.Text.joined", "Standard.Text.characters", "Standard.Text.uppercased",
        "Standard.Text.lowercased", "Standard.Text.encoded", "Standard.Text.decoded", "Standard.Text.trimmed",

        "Standard.Collection.count", "Standard.Collection.appending", "Standard.Collection.gathering",
        "Standard.Collection.keys", "Standard.Collection.setting",

        "Standard.Control.abort",

        "Standard.Concurrent.all", "Standard.Concurrent.first"
    ]

    // The procedures that are written in Warp from the builtin ones. Named by
    // what is left rather than listed, so a procedure added to a bundle lands
    // here unless it is put in the set above, and never in neither.
    static var derived: Set<Name> {
        Set(standard.flatMap(\.procedures.keys)).subtracting(builtinProcedures)
    }
}
