//
//  CastRefused.swift
//  Warp
//
//  Created by JSilver on 8/28/26.
//

import Foundation

// A value that did not arrive as the shape a cast named.
//
// Recoverable, and that is the whole reason it exists apart from the refusal a
// parameter's boundary raises. The two doors mean different things: an argument
// that does not fit the slot it was passed to is the *program* being wrong.
// Nobody could have expected it, and an `attempt` around it would swallow an
// author's mistake. A cast is the author saying "I expect this shape here",
// about data that arrived from outside, and being wrong about that is exactly
// what the world does. So it is a failure like any other, and an `attempt`
// catches it.
//
// `as?` reads the same mismatch as null instead. The two spellings are the
// two ways to say what should happen, and this is what the plain one does.
public struct CastRefused: RecoverableFailure {
    // MARK: - Property
    public let message: String

    // The shape the cast named, spelled the way the author wrote it.
    public let shape: String

    public let trace: Trace?

    public var type: String { Self.word }

    // The word this failure names itself by, said once so the link can read
    // it where it derives what a cast may fail with.
    public static let word = "cast_refused"

    // The shape that was named rides in the payload's box, for a rescue that
    // wants to say which cast it was.
    public var details: [Name: Value] { ["shape": .string(shape)] }

    // MARK: - Initializer
    public init(_ message: String, shape: String, trace: Trace? = nil) {
        self.message = message
        self.shape = shape
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> CastRefused {
        CastRefused(message, shape: shape, trace: trace)
    }
}
