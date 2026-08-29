//
//  Int+Spelling.swift
//  Warp
//
//  Created by JSilver on 8/24/26.
//

import Foundation

extension Int {
    // How a fraction reads as a machine word. The failures are different
    // facts — a fraction that is not a number holds no whole at all, digits
    // after the point are not a whole number, and a whole number past the
    // word has an answer no int holds — and every judge that meets a
    // fraction names the one that happened, so the reading lives in one
    // place rather than being re-derived beside each message.
    enum WordReading {
        case word(Int)
        case notANumber
        case fractional
        case pastTheWord
    }

    static func reading(_ fraction: Double) -> WordReading {
        guard !fraction.isNaN else { return .notANumber }

        // Infinity has a whole part, and it is past every word — the overflow
        // fact, not the no-number one.
        guard fraction.isFinite else { return .pastTheWord }

        guard fraction == fraction.rounded(.towardZero) else { return .fractional }

        guard let word = Int(exactly: fraction) else { return .pastTheWord }

        return .word(word)
    }

    // How a piece of text reads as a whole number's one spelling. The two
    // failures are different facts — text that is not the one spelling of
    // any whole number, and the one spelling of a whole number no int
    // holds — and every reader of a spelled whole names the one that
    // happened, so the grammar lives here alone.
    public enum Spelled {
        case word(Int)
        case notOneSpelling
        case pastTheWord
    }

    public static func reading(spelling: String) -> Spelled {
        guard let number = Int(spelling) else {
            // The parse missed: either the grammar did too, or the grammar
            // held and only the word could not.
            return wholeGrammar(spelling) ? .pastTheWord : .notOneSpelling
        }

        guard String(number) == spelling else { return .notOneSpelling }

        return .word(number)
    }

    // One value, one spelling: a candidate written `+1` or `007` is a second
    // spelling of a number that already has one, so reading it back must
    // reproduce the text exactly — `Int.init(_:)` alone accepts the aliases.
    // Public because the document readers hold the same line.
    public init?(spelling: String) {
        guard case let .word(number) = Int.reading(spelling: spelling) else { return nil }

        self = number
    }

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
