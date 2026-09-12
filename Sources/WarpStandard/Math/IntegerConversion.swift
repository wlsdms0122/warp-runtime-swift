//
//  IntegerConversion.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// A fraction read back as an int, after it was rounded. An int is 64 bits, so
// a fraction whose whole part is past its edge has no int to answer. That stops
// the run the way arithmetic off that edge does.
struct IntegerConversion: Sendable {
    // MARK: - Property
    private let procedure: String

    // MARK: - Initializer
    init(_ procedure: String) {
        self.procedure = procedure
    }

    // MARK: - Public
    // The reasons rounding can fail are different facts, and the refusal names
    // the one that happened. Through the one reading every judge of a fraction
    // shares.
    func of(_ rounded: Double, from asked: Double) throws -> Int {
        switch Int.reading(rounded) {
        case let .int(answered):
            return answered

        case .notANumber:
            throw ExecutionError("\(asked) has no whole answer")

        case .overflow:
            throw ExecutionError("\(procedure) of \(asked) overflows int")

        // The input already went through `rounded(_:)`, so digits after the
        // point cannot survive to here.
        case .fractional:
            preconditionFailure("a rounded fraction still had digits")
        }
    }

    // MARK: - Private
}
