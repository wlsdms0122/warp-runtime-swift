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
    // an answer keeps the spelling its receiver arrived in.
    //
    // `trimmed` stands here for a smaller reason: nothing names the characters
    // it removes, so a body written in Warp would have to invent the list.
    //
    // `regex` is in neither set. It cannot be written in Warp and it is asked
    // of no implementation, since what a pattern means differs between the
    // engines a host would reach for.
    static let builtin: Set<Name> = [
        "std.logic.equal",

        "std.math.plus", "std.math.minus", "std.math.times", "std.math.dividedBy",
        "std.math.remainder", "std.math.lessThan", "std.math.floored", "std.math.rounded",

        "std.text.text", "std.text.joined", "std.text.characters", "std.text.uppercased",
        "std.text.lowercased", "std.text.encoded", "std.text.decoded", "std.text.trimmed",

        "std.collection.count", "std.collection.appending", "std.collection.gathering",
        "std.collection.keys", "std.collection.setting",

        "std.control.abort",

        "std.concurrent.all", "std.concurrent.first"
    ]

    // The procedures that are written in Warp from the builtin ones. Named by
    // what is left rather than listed, so a procedure added to a bundle lands
    // here unless it is put in `builtin`, and never in neither.
    static var derived: Set<Name> {
        Set(standard.flatMap(\.procedures.keys)).subtracting(builtin).subtracting(["std.text.regex"])
    }
}
