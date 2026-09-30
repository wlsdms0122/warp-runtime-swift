//
//  GatheringQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Warp

// The collection's own elements, at the positions given and in their order.
//
// Said by position rather than built from values, which is what lets the
// answer keep the spelling the collection arrived in: bytes rearranged are bytes.
// A body that read the elements out and put them back would answer an array of
// numbers, because an array it started empty has no spelling to keep.
struct GatheringQuery: Query {
    // What this takes: the elements, and where in them to read.
    enum Parameters: Int, ParameterSet {
        case array
        case positions

        // MARK: - Property
        var declared: Parameter {
            switch self {
            case .array:
                return Parameter(name: "array", type: .array(.parameter(name: "Element")))

            case .positions:
                return Parameter(name: "positions", type: .array(.int))
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, so bytes are read where an array is, on either side.
        let collection = question[.array]

        guard let held = collection.elements, let given = question[.positions].elements else {
            throw ExecutionError("std.collection.gathering asks two arrays")
        }

        let positions = try given.map { position -> Int in
            guard case let .int(number) = position else {
                throw ExecutionError("std.collection.gathering asks whole positions")
            }

            // The collection is there and says how long it is, so a position it
            // does not hold read the length wrong. The same answer an index
            // written past the end gets.
            guard number >= 0, number < held.count else {
                throw ExecutionError(
                    "gathering asks position \(number) of \(held.count)"
                )
            }

            return number
        }

        return collection.elements(at: positions)
    }

    // MARK: - Private
}
