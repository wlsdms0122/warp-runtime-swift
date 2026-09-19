//
//  CountQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// How many, of what `std.Collection` admits.
struct CountQuery: Query {
    // What this takes: the thing counted, and nothing else.
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .named("std.Collection")) }
    }

    // MARK: - Property

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        switch question.receiver {
        case let .string(text):
            return .int(text.count)

        case let .record(record):
            return .int(record.count)

        case let .dictionary(held):
            return .int(held.count)

        case let .array(elements):
            return .int(elements.count)

        // Bytes have a length the way text has a count, and unlike text, no
        // Unicode question about what "one" means.
        case let .bytes(bytes):
            return .int(bytes.count)

        default:
            return nil
        }
    }

    // MARK: - Private
}
