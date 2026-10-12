//
//  IntSpelling.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// How a piece of text reads as a whole number's one spelling. The two failures
// are different facts (text that is not the one spelling of any whole number,
// and the one spelling of a whole number no `Int` holds) and every reader of a
// spelled whole names the one that happened, so the grammar lives here alone.
public enum IntSpelling {
    case int(Int)
    case notOneSpelling
    case overflow

    // MARK: - Property
    // MARK: - Initializer
    public init(_ text: String) {
        guard let number = Int(text) else {
            // The parse missed: either the grammar did too, or the grammar
            // held and only the `Int` could not.
            self = Self.wholeGrammar(text) ? .overflow : .notOneSpelling
            return
        }

        self = String(number) == text ? .int(number) : .notOneSpelling
    }

    // MARK: - Public
    // MARK: - Private
    // The one spelling's own grammar: `0`, or a `-` only when negative and
    // digits with no leading zero.
    private static func wholeGrammar(_ text: String) -> Bool {
        guard text != "0" else { return true }

        var digits = Substring(text)

        if digits.first == "-" { digits.removeFirst() }

        guard let first = digits.first, ("1"..."9").contains(first) else { return false }

        return digits.dropFirst().allSatisfy { digit in ("0"..."9").contains(digit) }
    }
}
