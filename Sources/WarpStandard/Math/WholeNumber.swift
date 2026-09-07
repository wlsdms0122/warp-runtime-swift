//
//  WholeNumber.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// A fraction read back as a machine word, after it was rounded. `int` is the
// machine word, so a fraction whose whole part is past it has no int to answer.
// That stops the run the way arithmetic off the word's edge does.
struct WholeNumber: Sendable {
    // MARK: - Property
    private let word: String

    // MARK: - Initializer
    init(_ word: String) {
        self.word = word
    }

    // MARK: - Public
    // The reasons rounding can fail are different facts, and the refusal names
    // the one that happened. Through the one reading every judge of a fraction
    // shares.
    func of(_ rounded: Double, from asked: Double) throws -> Int {
        switch Int.reading(rounded) {
        case let .word(answered):
            return answered

        case .notANumber:
            throw ExecutionError("\(asked) has no whole answer")

        case .pastTheWord:
            throw ExecutionError("\(word) of \(asked) overflows int")

        // The input already went through `rounded(_:)`, so digits after the
        // point cannot survive to here.
        case .fractional:
            preconditionFailure("a rounded fraction still had digits")
        }
    }

    // MARK: - Private
}
