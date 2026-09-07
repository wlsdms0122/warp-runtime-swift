//
//  ReduceQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// The elements folded into one, starting from a value.
struct ReduceQuery: Query {
    // What this takes: where the fold starts, the elements, and the body that
    // folds. The body is offered the answer so far as `carried` and the element
    // as `item`.
    enum Parameters: Int, ParameterSet {
        case from
        case of
        case value

        var name: Name {
            switch self {
            case .from:
                return "from"

            case .of:
                return "of"

            case .value:
                return "value"
            }
        }

        var declared: Parameter {
            switch self {
            case .from:
                return Parameter(type: .parameter(name: "Carried"))

            case .of:
                return Parameter(type: .array(.parameter(name: "Element")))

            case .value:
                return Parameter(
                    type: .procedure(
                        Signature(
                            parameters: [
                                "carried": Parameter(type: .parameter(name: "Carried")),
                                "item": Parameter(type: .parameter(name: "Element"))
                            ],
                            returns: .parameter(name: "Carried")
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
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        let body = question[.value]

        return try elements.reduce(question[.from]) { carried, element in
            try question.call(
                body,
                with: [(name: "carried", value: carried), (name: "item", value: element)]
            )
        }
    }

    // MARK: - Private
}
