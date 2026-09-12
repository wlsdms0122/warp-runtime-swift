//
//  MapQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// Each element answered by a procedure, in order. The procedure parameter is
// declared `pure procedure`, so what arrives is something the link proved
// answers without running, which is what lets this be a procedure rather than a
// construct the grammar had to grow.
struct MapQuery: Query {
    // What this takes: the elements, and the body each is offered to. What the
    // body is handed is named the way `iteration` names what it binds: the
    // element is `item`. Fixed rather than taken from the order the procedure
    // declared them in, because a declaration is a mapping and a mapping has no
    // order.
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
                            returns: .parameter(name: "Answer")
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
    func evaluate(_ question: Question<Self>) throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, so a walk reads bytes the way `each` does.
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        let body = question[.value]

        // What the procedure answered is its own value, whatever it was reached
        // from, which is why the declaration names a second parameter for it
        // and why the receiver's spelling has nothing to say here.
        return .array(
            try elements.map { element in
                try question.call(body, with: [(name: "item", value: element)])
            }
        )
    }

    // MARK: - Private
}
