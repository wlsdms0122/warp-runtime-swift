//
//  CountQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// How many. Answers nil for shapes that have no count, which is what makes
// `x.count` read as absent rather than fail when `x` is a number.
struct CountQuery: Query {
    // What this takes: the thing counted, and nothing else.
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .any) }
    }

    // MARK: - Property

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        switch question.receiver {
        case let .string(text):
            return .int(text.count)

        case let .record(record):
            return .int(record.count)

        case let .dictionary(held):
            return .int(held.count)

        // What is indexed (an array, or bytes through the one projection that
        // owns the equation) is counted the same way. Bytes have a length the
        // way text has a count, and unlike text, no Unicode question about what
        // "one" means.
        default:
            guard let elements = question.receiver?.elements else { return nil }

            return .int(elements.count)
        }
    }

    // MARK: - Private
}
