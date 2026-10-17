//
//  IntegerConversion.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// A fraction read back as an `Int`, after it was rounded. An `Int` is 64
// bits, so a fraction whose whole part is past its edge has no `Int` to
// answer. That stops the run the way arithmetic off that edge does.
struct IntegerConversion: Sendable {
    // MARK: - Property
    private let procedure: String

    // MARK: - Initializer
    init(_ procedure: String) {
        self.procedure = procedure
    }

    // MARK: - Public
    // The whole a fraction rounds to, refused where it is past the `Int`'s
    // own edge, which no `Int` holds. Rounding is done here, so the fraction
    // read back has no digits after the point to refuse.
    func of(_ asked: Double, rounded rule: FloatingPointRoundingRule) throws -> Int {
        guard let answered = Int(exactly: asked.rounded(rule)) else {
            throw ExecutionError("\(procedure) of \(asked) overflows Int")
        }

        return answered
    }

    // MARK: - Private
}
