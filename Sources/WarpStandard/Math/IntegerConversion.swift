//
//  IntegerConversion.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// A floating-point number read back as an `Int`, after it was rounded. An
// `Int` is 64 bits, so a floating-point number whose whole part is past its
// edge has no `Int` to return. That stops the run the way arithmetic off that
// edge does.
struct IntegerConversion: Sendable {
    // MARK: - Property
    private let procedure: String

    // MARK: - Initializer
    init(_ procedure: String) {
        self.procedure = procedure
    }

    // MARK: - Public
    // The integer a floating-point number rounds to, refused where it is past
    // the `Int`'s own edge, which no `Int` holds. Rounding is done here, so the
    // floating-point number read back has no digits after the point to refuse.
    func of(_ asked: Double, rounded rule: FloatingPointRoundingRule) throws -> Int {
        guard let integer = Int(exactly: asked.rounded(rule)) else {
            throw ExecutionError("\(procedure) of \(asked) overflows Int")
        }

        return integer
    }

    // MARK: - Private
}
