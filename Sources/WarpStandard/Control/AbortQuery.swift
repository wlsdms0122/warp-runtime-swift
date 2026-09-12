//
//  AbortQuery.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

// Leaving instead of answering. The only procedure that never returns, which is what
// `returns: never` on its declaration says and what lets the arm that leaves
// stay out of the type the arm that stays decides.
//
// The refusal it raises carries the recoverable marker, so `attempt` around it
// catches it and nothing else does.
struct AbortQuery: Query {
    // What this takes: the message it refuses with. Anything spells, so a
    // refusal can name what it was holding rather than only a sentence
    // written ahead of time. It is required: a refusal with nothing to say
    // is the one shape this procedure exists to prevent.
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .any) }
    }

    // MARK: - Property
    let failing = Failing.these([Aborted.word])

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        guard let message = question.receiver else {
            throw ExecutionError("abort refuses with a message, and none arrived")
        }

        throw Aborted(Rendering(message).text())
    }

    // MARK: - Private
}
