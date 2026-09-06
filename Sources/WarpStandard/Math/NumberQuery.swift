//
//  NumberQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// The readings of a single number. Each takes nothing beyond its receiver, so
// each is reachable from a path.
//
// `floored` and `rounded` answer an int whatever they were sent, which is how a
// quotient becomes a whole number again. `dividedBy` always answers a double,
// and this is the other half of writing a whole division. `int` is the machine
// word, so a fraction whose whole part is past it has no int to answer. That
// stops the run the way arithmetic off the word's edge does.
struct NumberQuery: Query {
    enum Reading: Sendable {
        case absolute
        case floored
        case rounded
    }

    // MARK: - Property
    private let reading: Reading

    // MARK: - Initializer
    public init(_ reading: Reading) {
        self.reading = reading
    }

    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        switch (reading, question.receiver) {
        case let (.absolute, .int(number)):
            // The one magnitude the word does not hold is its own minimum.
            guard let answered = Int(exactly: number.magnitude) else {
                throw ExecutionError("absolute of \(number) overflows int")
            }

            return .int(answered)

        case let (.absolute, .double(real)):
            return .double(abs(real))

        case let (.floored, .int(whole)), let (.rounded, .int(whole)):
            return .int(whole)

        case let (.floored, .double(real)):
            return .int(try whole(real.rounded(.down), from: real))

        case let (.rounded, .double(real)):
            return .int(try whole(real.rounded(), from: real))

        default:
            return nil
        }
    }

    // MARK: - Private
    // The reasons rounding can fail are different facts, and the refusal names
    // the one that happened. Through the one reading every judge of a fraction
    // shares.
    private func whole(_ rounded: Double, from asked: Double) throws -> Int {
        switch Int.reading(rounded) {
        case let .word(answered):
            return answered

        case .notANumber:
            throw ExecutionError("\(asked) has no whole answer")

        case .pastTheWord:
            throw ExecutionError("\(reading) of \(asked) overflows int")

        // The input already went through `rounded(_:)`, so digits after the
        // point cannot survive to here.
        case .fractional:
            preconditionFailure("a rounded fraction still had digits")
        }
    }
}
