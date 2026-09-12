//
//  ConcurrentFailed.swift
//  WarpStandard
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

// Every piece's failure, keyed by the piece's label. One aggregate rather than
// whichever failure finished first, because which one that is would be timing.
// A rescue reads the same set of failures on every run.
public struct ConcurrentFailed: RecoverableFailure {
    // MARK: - Property
    public let failures: [Name: String]

    public var type: String { Self.word }


    // The procedure this failure names itself by, said once so a declaration can

    // read it where it says what it may fail with.

    public static let word = "concurrent_failed"

    public var details: [Name: Value] {
        ["failures": .dictionary(failures.mapValues(Value.string))]
    }

    public var message: String {
        "concurrent pieces failed: "
            + failures
                .sorted { left, right in left.key < right.key }
                .map { piece, reason in "\(piece): \(reason)" }
                .joined(separator: "; ")
    }

    public let trace: Trace?

    // MARK: - Initializer
    public init(failures: [Name: String], trace: Trace? = nil) {
        self.failures = failures
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> ConcurrentFailed {
        ConcurrentFailed(failures: failures, trace: trace)
    }

    // MARK: - Private
}
