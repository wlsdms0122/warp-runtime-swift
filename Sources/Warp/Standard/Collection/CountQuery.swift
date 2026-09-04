//
//  CountQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// How many. Answers nil for shapes that have no count, which is what makes
// `x.count` read as absent rather than fail when `x` is a number.
public struct CountQuery: Query {
    // MARK: - Property

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        switch question.receiver {
        case let .string(text):
            return .int(text.count)

        case let .record(record):
            return .int(record.count)

        case let .dictionary(held):
            return .int(held.count)

        // What is indexed — an array, or bytes through the one projection
        // that owns the equation — is counted the same way. Bytes have a
        // length the way text has a count, and unlike text, no Unicode
        // question about what "one" means.
        default:
            guard let elements = question.receiver?.elements else { return nil }

            return .int(elements.count)
        }
    }

    // MARK: - Private
}
