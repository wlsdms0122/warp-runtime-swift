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
// The procedure's own spelling comes in because these refusals name the procedure that
// was sent, and a caller acts on that name.
struct Ordering: Sendable {
    // MARK: - Property
    private let procedure: String

    // MARK: - Initializer
    init(_ procedure: String) {
        self.procedure = procedure
    }

    // MARK: - Public
    // How the two stand, with the pair the caller picks from. A pair with no
    // order is refused rather than answered false or picked from: false claims
    // the opposite comparison would say something, and it would not.
    func of(_ first: Value, and operand: Value) throws -> (ComparisonResult, Value) {
        guard let order = Value.order(first, operand) else {
            throw ExecutionError(
                "\(procedure) asks \(first.type) and"
                    + " \(operand.type), which have no order."
                    + " It takes two numbers or two strings"
            )
        }

        return (order, first)
    }

    // MARK: - Private
}
