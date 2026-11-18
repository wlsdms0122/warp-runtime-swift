//
//  RunRefused.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

public struct RunRefused: WarpError {
    // MARK: - Property
    public let message: String

    public let trace: Trace?

    // MARK: - Initializer
    public init(_ message: String, trace: Trace? = nil) {
        self.message = message
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> RunRefused {
        RunRefused(message, trace: trace)
    }

    // MARK: - Private
}
