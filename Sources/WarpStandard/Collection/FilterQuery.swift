//
//  FilterQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// The elements a procedure answers true for.
struct FilterQuery: Query {
    // What this takes: the elements, and the body that judges each. The body is
    // offered the element as `item`.
    enum Parameters: Int, ParameterSet {
        case of
        case value

        var name: Name {
            switch self {
            case .of:
                return "of"

            case .value:
                return "value"
            }
        }

        var declared: Parameter {
            switch self {
            case .of:
                return Parameter(type: .array(.parameter(name: "Element")))

            case .value:
                return Parameter(
                    type: .procedure(
                        Signature(
                            parameters: ["item": Parameter(type: .parameter(name: "Element"))],
                            returns: .bool
                        ),
                        .pure
                    )
                )
            }
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        let body = question[.value]

        var kept: [Value] = []

        for element in elements {
            let verdict = try await question.call(body, with: [(name: "item", value: element)])

            guard case let .bool(keeping) = verdict else {
                throw ExecutionError(
                    "filter asks a procedure answering bool, and this one"
                        + " answered \(verdict.type)"
                )
            }

            guard keeping else { continue }

            kept.append(element)
        }

        // The receiver's own elements, fewer of them, so the spelling stands.
        return receiver.respelled(kept)
    }

    // MARK: - Private
}
