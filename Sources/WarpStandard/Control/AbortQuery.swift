//
//  AbortQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/23/26.
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
    // written ahead of time. Null spells as `null`, and a refusal saying that
    // word would be saying nothing, so null says `aborted`.
    enum Parameters: Int, ParameterSet {
        case message

        // MARK: - Property
        var declared: Parameter { Parameter(name: "message", type: .any) }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    let failing = Failing.these([Aborted.type])

    static let unsaid = "aborted"

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        let message = question[.message]

        guard message != .null else {
            throw Aborted(Self.unsaid)
        }

        throw Aborted(Rendering(message).text())
    }

    // MARK: - Private
}
