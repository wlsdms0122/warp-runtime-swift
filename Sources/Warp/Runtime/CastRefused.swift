//
//  CastRefused.swift
//  Warp
//
//  Created by JSilver on 8/28/26.
//

import Foundation

// A value that did not arrive as the type a cast named. A cast is the author
// saying what they expect of a value the build could not type, and a value
// being otherwise is what the world does, so it is a failure like any other,
// and an `attempt` catches it. A value from outside that does not fit a door
// refuses the run instead.
//
// `as?` reads the same mismatch as null instead. The two spellings are the
// two ways to say what should happen, and this is what the plain one does.
public struct CastRefused: RecoverableFailure {
    // MARK: - Property
    public let message: String

    // The type the cast reads as, so a cast to an alias names the type the
    // alias stands for, in its string spelling.
    public let expected: String

    // The type the value arrived as an instance of. The other half of the
    // fact: what was asked for is knowable from the text, and what came is
    // not.
    public let actual: String

    public let trace: Trace?

    public var type: String { Self.type }

    // What this failure names itself, said once so the build can read it where
    // it reads what a cast may fail with.
    public static let type = "cast_refused"

    // Both halves ride in the payload's box, so a rescue can say which cast
    // it was and branch on what turned up.
    public var details: Value.Dictionary {
        Value.Dictionary(["expected": .string(expected), "actual": .string(actual)])
    }

    // MARK: - Initializer
    // A value that did not fit the type a cast reads as. Both halves are
    // spelled here, as `details` holds them: the type by its string spelling
    // and the value's type by its name.
    init(_ message: String, expected: LoweredType, actual: Value, in table: LoweredTypeTable) {
        self.init(message, expected: expected.rendered(in: table), actual: actual.nominal.spelling, trace: nil)
    }

    private init(_ message: String, expected: String, actual: String, trace: Trace?) {
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
