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
        case collection

        // MARK: - Property
        var declared: Parameter {
            Parameter(name: "collection", type: .named("std.Collection"))
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        switch question[.collection] {
        case let .string(text):
            return .int(text.count)

        case let .array(elements):
            return .int(elements.count)

        case let .bytes(bytes):
            return .int(bytes.count)

        case let .record(record):
            return .int(record.count)

        case let .dictionary(held):
            return .int(held.count)

        default:
            throw ExecutionError("std.collection.count asks a collection")
        }
    }

    // MARK: - Private
}
