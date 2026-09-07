//
//  Ordering.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The one order. Whether a pair may be ordered and how is decided here and
// nowhere else, so `min` cannot drift from what `lessThan` reads. Numbers by
// worth, exactly at every size, and strings lexicographically.
//
// The word's own spelling comes in because these refusals name the word that
// was sent, and a caller acts on that name.
struct Ordering: Sendable {
    // MARK: - Property
    private let word: String

    // MARK: - Initializer
    init(_ word: String) {
        self.word = word
    }

    // MARK: - Public
    // How the two stand, with the pair the caller picks from. A pair with no
    // order is refused rather than answered false or picked from: false claims
    // the opposite comparison would say something, and it would not.
    func of(_ receiver: Value?, and operand: Value) throws -> (ComparisonResult, Value) {
        // Its own refusal for an absent left side. These words order, so
        // arithmetic's "expected two numbers" would name a domain they do not
        // have.
        guard let receiver else {
            throw ExecutionError("\(word) asks two of a kind, and nothing arrived to order")
        }

        guard let order = Value.order(receiver, operand) else {
            throw ExecutionError(
                "\(word) asks \(receiver.type) and"
                    + " \(operand.type), which have no order."
                    + " It takes two numbers or two strings"
            )
        }

        return (order, receiver)
    }

    // MARK: - Private
}
