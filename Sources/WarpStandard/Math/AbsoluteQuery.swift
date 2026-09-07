//
//  AbsoluteQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The number without its sign. Takes nothing beyond its receiver, so it is
// reachable from a path.
struct AbsoluteQuery: Query {
    // What this takes: the number, and nothing else.
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter {
            Parameter(type: .parameter(name: "N", constraint: "std.Numeric"))
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        switch question.receiver {
        case let .int(number):
            // The one magnitude the word does not hold is its own minimum.
            guard let answered = Int(exactly: number.magnitude) else {
                throw ExecutionError("absolute of \(number) overflows int")
            }

            return .int(answered)

        case let .double(real):
            return .double(abs(real))

        default:
            return nil
        }
    }

    // MARK: - Private
}
