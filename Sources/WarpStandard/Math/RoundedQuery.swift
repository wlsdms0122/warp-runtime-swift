//
//  RoundedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The nearest whole number. Answers an int whatever it was sent, the same as
// `floored`.
struct RoundedQuery: Query {
    typealias Parameters = NumberReceiver

    // MARK: - Property
    private let whole = WholeNumber("rounded")

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        switch question.receiver {
        case let .int(number):
            return .int(number)

        case let .double(real):
            return .int(try whole.of(real.rounded(), from: real))

        default:
            return nil
        }
    }

    // MARK: - Private
}
