//
//  CountQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// How many, for every type answering `Standard.Collection`.
struct CountQuery: Query {
    // What this takes: the thing counted, and nothing else. The type is
    // each declaration's own, since one query counts for every type that
    // has a count.
    enum Parameters: Int, ParameterSet {
        case collection

        // MARK: - Property
        var declared: Parameter {
            Parameter(name: "collection")
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The declared spelling, which a refusal names.
    private let procedure: String

    // MARK: - Initializer
    init(answering procedure: String) {
        self.procedure = procedure
    }

    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        let collection = question[.collection]

        if let elements = collection.elements { return .int(elements.count) }

        switch collection {
        case let .string(text):
            return .int(text.count)

        case let .record(record):
            return .int(record.count)

        case let .dictionary(held):
            return .int(held.count)

        default:
            throw ExecutionError("\(procedure) asks a collection")
        }
    }

    // MARK: - Private
}
