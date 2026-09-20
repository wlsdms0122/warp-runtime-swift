//
//  TrimmedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The text without the whitespace at either end.
//
// What counts as whitespace is Unicode's `White_Space` property and nothing
// a platform adds to it: a character goes only if every one of its code points
// has it. That is what keeps `\r\n`, which is one character and two code
// points, removable, and what keeps a space carrying a combining mark, which is
// also one character and two code points, where it was written.
struct TrimmedQuery: Query {
    typealias Parameters = StringReceiver

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        // Not a string is not a failure here. A path that asks a string procedure
        // of a number reads as absence, the same as a field never set.
        guard case let .string(text) = question.receiver else { return nil }

        let trimmed = text.drop(while: Self.isWhitespace)
            .reversed().drop(while: Self.isWhitespace).reversed()

        return .string(String(trimmed))
    }

    // MARK: - Private
    private static func isWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in scalar.properties.isWhitespace }
    }
}
