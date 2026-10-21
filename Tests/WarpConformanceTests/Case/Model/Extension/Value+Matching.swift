//
//  Value+Matching.swift
//  WarpConformanceTests
//
//  Created by JSilver on 10/21/26.
//

import Foundation
import Warp

extension Value {
    // Whether this value matches what a case expects: of one kind and one
    // spelling, part by part. A fraction's spelling is its binary64, so a
    // fraction matches only the same bits, `-0.0` not `0.0`. Text matches as
    // values compare it.
    func matchesStrictly(_ expected: Value) -> Bool {
        switch (self, expected) {
        case let (.double(mine), .double(theirs)):
            return mine.bitPattern == theirs.bitPattern

        case let (.array(mine), .array(theirs)):
            return mine.count == theirs.count
                && zip(mine, theirs).allSatisfy { held, written in held.matchesStrictly(written) }

        case let (.dictionary(mine), .dictionary(theirs)):
            return mine.entries.count == theirs.entries.count
                && zip(mine.entries, theirs.entries).allSatisfy { held, written in
                    held.key.matchesStrictly(written.key) && held.value.matchesStrictly(written.value)
                }

        case let (.struct(mine), .struct(theirs)):
            return mine.layout == theirs.layout
                && zip(mine.values, theirs.values).allSatisfy { held, written in held.matchesStrictly(written) }

        default:
            return self == expected
        }
    }
}
