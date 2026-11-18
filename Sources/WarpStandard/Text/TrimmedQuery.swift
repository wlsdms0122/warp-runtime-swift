//
//  TrimmedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The string without the whitespace at either end.
//
// What counts as whitespace is Unicode's `White_Space` property and nothing
// a platform adds to it: a character goes only if every one of its code points
// has it. That is what keeps `\r\n`, which is one character and two code
// points, removable, and what keeps a space carrying a combining mark, which is
// also one character and two code points, where it was written.
struct TrimmedQuery: Computation {
    typealias Parameters = StringOperand

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func compute(_ arguments: Arguments<Self>) throws -> Value {
        guard case let .string(text) = arguments[.text] else {
            throw RunRefused("Standard.Text.trimmed asks a String")
        }

        let trimmed = text.drop(while: Self.isWhitespace)
            .reversed().drop(while: Self.isWhitespace).reversed()

        return .string(String(trimmed))
    }

    // MARK: - Private
    private static func isWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in scalar.properties.isWhitespace }
    }
}
