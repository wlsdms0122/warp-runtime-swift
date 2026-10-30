//
//  ConcurrentFailed.swift
//  WarpStandard
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

// Every piece's failure, under the piece's key, each the envelope the
// piece raised: a dictionary's piece under the key it stood under, a list's under
// its position. One aggregate rather than whichever failure finished first,
// because which one that is would be timing. A catch reads the same set of
// failures on every run, and reads each piece's own type and details.
public struct ConcurrentFailed: RecoverableFailure {
    // MARK: - Property
    public let failures: Value.Dictionary

    public var type: String { Self.type }

    // What this failure names itself, said once so a declaration can read it
    // where it says what it may fail with.
    public static let type = "concurrent_failed"

    public var details: Value.Dictionary {
        Value.Dictionary(["failures": .dictionary(failures)])
    }

    public var message: String {
        "concurrent pieces failed: "
            + failures.entries
                .map { key, envelope in
                    let piece = Rendering(key).text()

                    guard case let .string(message)? = envelope[FailurePayload.message] else { return piece }

                    return "\(piece): \(message)"
                }
                .joined(separator: "; ")
    }

    public let trace: Trace?

    // MARK: - Initializer
    public init(failures: Value.Dictionary, trace: Trace? = nil) {
        self.failures = failures
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> ConcurrentFailed {
        ConcurrentFailed(failures: failures, trace: trace)
    }

    // MARK: - Private
}
