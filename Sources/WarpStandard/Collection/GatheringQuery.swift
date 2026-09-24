//
//  GatheringQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Warp

// The receiver's own elements, at the positions given and in their order.
//
// Said by position rather than built from values, which is what lets the
// answer keep the spelling the receiver arrived in: bytes rearranged are bytes.
// A body that read the elements out and put them back would answer an array of
// numbers, because an array it started empty has no spelling to keep.
struct GatheringQuery: Query {
    // What this takes: the elements, and where in them to read.
    enum Parameters: Int, ParameterSet {
        case of
        case value

        var declared: Parameter {
            switch self {
            case .of:
                return Parameter(name: "of", type: .array(.parameter(name: "Element")))

            case .value:
                return Parameter(name: "value", type: .array(.int))
            }
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, so bytes are read where an array is.
        guard let receiver = question.receiver, let held = receiver.elements else { return nil }

        guard case let .array(given) = question[.value] else {
            throw ExecutionError(
                "gathering asks an array of positions, and"
                    + " \(question[.value].type) arrived"
            )
        }

        let positions = try given.map { position -> Int in
            guard case let .int(number) = position else {
                throw ExecutionError("gathering asks whole numbers, and \(position.type) arrived")
            }

            // The receiver is there and says how long it is, so a position it
            // does not hold read the length wrong. The same answer an index
            // written past the end gets.
            guard number >= 0, number < held.count else {
                throw ExecutionError(
                    "gathering asks position \(number) of \(held.count)"
                )
            }

            return number
        }

        return receiver.elements(at: positions)
    }

    // MARK: - Private
}
