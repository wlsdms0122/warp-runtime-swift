//
//  Effect.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A procedure implemented natively that answers by reaching outside the run.
// Anything with a clock, a device or another process behind it. Same
// declaration, same call as a query; the difference is that it runs, so it
// is asynchronous and cannot be asked inside a condition.
//
// An effect is declared, not embedded. The grammar stays closed. A module adds
// vocabulary, never a new kind of expression, so nothing installed can quietly
// redefine what `loop` means.
public protocol Effect: Sendable {
    // Whether this touches no name another body could touch at the same time.
    // A word holding state between calls says false, and the link stops
    // deriving isolation through it and through whatever calls it.
    var isolated: Bool { get }

    // What may come out of this when the work goes wrong, by the words its
    // failures name themselves. A word that only ever throws at an author
    // mistake fails nothing, which is the default, so a word that can fail
    // says so and one that could fail anything says `unstated`.
    var failing: Failing { get }

    func run(_ invocation: Invocation) async throws -> Value
}

public extension Effect {
    var isolated: Bool { true }

    var failing: Failing { .these([]) }
}
