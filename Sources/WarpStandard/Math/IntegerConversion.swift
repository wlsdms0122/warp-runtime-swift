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
    // The whole a fraction rounds to. The reasons there is none are
    // different facts, and the refusal names the one that happened: a
    // fraction that is not a number has no whole at all, and a rounded
    // whole past the int's own edge is one no int holds. Rounding is done
    // here, so what is narrowed has no digits after the point to refuse.
    func of(_ asked: Double, rounded rule: FloatingPointRoundingRule) throws -> Int {
        guard !asked.isNaN else {
            throw ExecutionError("\(procedure) of \(asked) has no whole answer")
        }

        guard let answered = Int(exactly: asked.rounded(rule)) else {
            throw ExecutionError("\(procedure) of \(asked) overflows Int")
        }

        return answered
    }

    // MARK: - Private
}
