//
//  FlooredQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The whole number at or below this one. Answers an int whatever it was sent,
// which is how a quotient becomes a whole number again: `dividedBy` always
// answers a double, and this is the other half of writing a whole division.
struct FlooredQuery: Query {
    typealias Parameters = NumberReceiver

    // MARK: - Property
    private let integer = IntegerConversion("floored")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        switch question.receiver {
        case let .int(number):
            return .int(number)

        case let .double(real):
            return .int(try integer.of(real.rounded(.down), from: real))

        default:
            return nil
        }
    }

    // MARK: - Private
}
