//
//  WalkingQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// Walking an array with a procedure the caller wrote. Each declares its
// procedure parameter `pure procedure`, so what arrives is something the link
// proved answers without running — which is what lets these be words rather
// than constructs the grammar had to grow.
//
// What a walk hands the procedure it was given is named the way `iteration`
// names what it binds: the element is `item`, and a reduction's answer so far is
// `carried`. Fixed rather than taken from the order the procedure declared them
// in, because a declaration is a mapping and a mapping has no order.
public struct WalkingQuery: Query {
    public enum Walk: Sendable {
        case map
        case filter
        case reduce
    }

    // MARK: - Property
    private let walk: Walk

    // MARK: - Initializer
    public init(_ walk: Walk) {
        self.walk = walk
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, so a walk reads bytes the way `each` does.
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        let body = question["value"]

        switch walk {
        // What the procedure answered is its own value, whatever it was reached
        // from — which is why the declaration names a second parameter for it
        // and why the receiver's spelling has nothing to say here.
        case .map:
            return .array(
                try elements.map { element in
                    try question.call(body, with: [(name: "item", value: element)])
                }
            )

        // The receiver's own elements, fewer of them — so the spelling stands.
        case .filter:
            return receiver.respelled(
                try elements.filter { element in
                    let verdict = try question.call(body, with: [(name: "item", value: element)])

                    guard case let .bool(kept) = verdict else {
                        throw ExecutionError(
                            "filter asks a procedure answering bool, and this one"
                                + " answered \(verdict.type)"
                        )
                    }

                    return kept
                }
            )

        case .reduce:
            return try elements.reduce(question["from"]) { carried, element in
                try question.call(body, with: [(name: "carried", value: carried), (name: "item", value: element)])
            }
        }
    }

    // MARK: - Private
}
