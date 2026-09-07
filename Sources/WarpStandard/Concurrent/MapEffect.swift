//
//  MapEffect.swift
//  WarpStandard
//
//  Created by JSilver on 8/22/26.
//

import Foundation
import Warp

// Runs one closure once per element, and answers in the collection's order. The
// concurrent reading of what `each` walks.
struct MapEffect: Effect {
    // What this takes: the elements, and the body each is run under. The body
    // is offered the element as `item` and where it sat as `index`, and its own
    // signature says which of those it reads.
    enum Parameters: Int, ParameterSet {
        case by
        case over

        var name: Name {
            switch self {
            case .by:
                return "by"

            case .over:
                return "over"
            }
        }

        var declared: Parameter {
            switch self {
            case .by:
                return Parameter(
                    type: .procedure(
                        Signature(
                            parameters: [
                                "item": Parameter(type: .parameter(name: "Element")),
                                "index": Parameter(type: .int)
                            ],
                            returns: .parameter(name: "Answer")
                        ),
                        .unstated,
                        .isolated
                    )
                )

            case .over:
                return Parameter(type: .array(.parameter(name: "Element")))
            }
        }
    }

    // MARK: - Property
    let failing = Failing.these([ConcurrentFailed.word])

    private let fanout = Fanout("std.concurrent.map")

    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await fanout.map(
            invocation,
            over: invocation.receiver ?? .null,
            by: invocation[.by]
        )
    }

    // MARK: - Private
}
