//
//  UndeclaredTypeError.swift
//  Warp
//
//  Created by JSilver on 8/28/26.
//

import Foundation

// A declaration naming a type or constraint nothing declares.
//
// Its own error because it is its own kind of wrong: every other refusal a
// boundary raises says the value that arrived was not what was declared, and
// this one says the *declaration* never named anything. The two look alike
// from the outside — both stop a value at a boundary — and a reader that
// cannot tell them apart will treat a typo as an answer.
//
// `as?` is that reader. It exists to read "the value is not that shape" as
// null, which is the author saying they expected a mismatch; a name nothing
// declares is not a mismatch they could have expected, and swallowing one
// would turn a typo into a permanent, silent null.
public struct UndeclaredTypeError: WarpError {
    // MARK: - Property
    public let message: String

    public let trace: Trace?

    // MARK: - Initializer
    public init(_ message: String, trace: Trace? = nil) {
        self.message = message
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> UndeclaredTypeError {
        UndeclaredTypeError(message, trace: trace)
    }

    // MARK: - Private
}
