//
//  Aborted.swift
//  WarpStandard
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

public struct Aborted: RecoverableFailure {
    // MARK: - Property
    public let message: String

    public let type = "aborted"

    public let trace: Trace?

    // MARK: - Initializer
    public init(_ message: String, trace: Trace? = nil) {
        self.message = message
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> Aborted {
        Aborted(message, trace: trace)
    }

    // MARK: - Private
}
