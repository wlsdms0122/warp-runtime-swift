//
//  Value+Matching.swift
//  WarpConformanceTests
//
//  Created by JSilver on 10/21/26.
//

import Foundation
import Warp

extension Value {
    // How text matches what a case expects. What a reading answers is a
    // spelling, so its text matches by its Unicode scalars, exactly; what a
    // run answers is a value, so its text matches as values compare it.
    enum TextMatching {
        case scalars
        case value
    }

    // Whether this value matches what a case expects: of one kind and one
    // spelling, part by part. A fraction's spelling is its binary64, so a
    // fraction matches only the same bits, `-0.0` not `0.0`.
    func matchesStrictly(_ expected: Value, text: TextMatching) -> Bool {
        switch (self, expected) {
        case let (.double(mine), .double(theirs)):
            return mine.bitPattern == theirs.bitPattern

        case let (.string(mine), .string(theirs)):
            switch text {
            case .scalars: return mine.unicodeScalars.elementsEqual(theirs.unicodeScalars)
            case .value: return mine == theirs
            }

        case let (.array(mine), .array(theirs)):
            return mine.count == theirs.count
                && zip(mine, theirs).allSatisfy { held, written in held.matchesStrictly(written, text: text) }

        case let (.dictionary(mine), .dictionary(theirs)):
            return mine.entries.count == theirs.entries.count
                && zip(mine.entries, theirs.entries).allSatisfy { held, written in
                    held.key.matchesStrictly(written.key, text: text)
                        && held.value.matchesStrictly(written.value, text: text)
                }

        case let (.struct(mine), .struct(theirs)):
            return mine.layout == theirs.layout
                && zip(mine.values, theirs.values).allSatisfy { held, written in held.matchesStrictly(written, text: text) }

        default:
            return self == expected
        }
    }
}
