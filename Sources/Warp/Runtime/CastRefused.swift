//
//  CastRefused.swift
//  Warp
//
//  Created by JSilver on 8/28/26.
//

import Foundation

// A value that did not arrive as the type a cast named.
//
// Recoverable, and that is the whole reason it exists apart from the refusal a
// parameter's boundary raises. The two doors mean different things: an argument
// that does not fit the slot it was passed to is the *program* being wrong.
// Nobody could have expected it, and an `attempt` around it would swallow an
// author's mistake. A cast is the author saying "I expect this type here",
// about data that arrived from outside, and being wrong about that is exactly
// what the world does. So it is a failure like any other, and an `attempt`
// catches it.
//
// `as?` reads the same mismatch as null instead. The two spellings are the
// two ways to say what should happen, and this is what the plain one does.
public struct CastRefused: RecoverableFailure {
    // MARK: - Property
    public let message: String

    // The type the cast named, spelled the way the author wrote it.
    public let expected: String

    // The type the value arrived as an instance of. The other half of the
    // fact: what was asked for is knowable from the text, and what came is
    // not.
    public let actual: String

    public let trace: Trace?

    public var type: String { Self.type }

    // What this failure names itself, said once so the build can read it where
    // it derives what a cast may fail with.
    public static let type = "cast_refused"

    // Both halves ride in the payload's box, so a rescue can say which cast
    // it was and branch on what turned up.
    public var details: [Name: Value] {
        ["expected": .string(expected), "actual": .string(actual)]
    }

    // MARK: - Initializer
    public init(_ message: String, expected: String, actual: String, trace: Trace? = nil) {
        self.message = message
        self.expected = expected
        self.actual = actual
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> CastRefused {
        CastRefused(message, expected: expected, actual: actual, trace: trace)
    }

    // MARK: - Private
}
