//
//  ContainsQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

struct ContainsQuery: Query {
    // MARK: - Property

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        // Absence answers false rather than failing: asking whether nothing
        // contains something has an obvious answer.
        guard let receiver = question.receiver, receiver != .null else { return .bool(false) }

        let operand = question["value"]

        switch receiver {
        case let .string(text):
            guard case let .string(part) = operand else {
                throw ExecutionError("contains asks a non-string part of a string")
            }

            return .bool(text.contains(part))

        // The receiver is declared `any` for the string case, so what is
        // indexed (an array, or bytes through the one projection that owns the
        // equation) is read here rather than settled at the boundary.
        default:
            guard let elements = receiver.elements else {
                throw ExecutionError(
                    "contains asks \(receiver.type), expected string or array"
                )
            }

            return .bool(elements.contains { element in element.matches(operand) })
        }
    }

    // MARK: - Private
}
