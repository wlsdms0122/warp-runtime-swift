//
//  ReferenceUnfit.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// A path a run reads that does not reach a value. The reason names the
// path as far as the step that failed.
public struct ReferenceUnfit: WarpError {
    // MARK: - Property
    public let path: Path
    public let reason: String

    public var message: String {
        reason
    }

    public let trace: Trace?

    // MARK: - Initializer
    public init(path: Path, reason: String, trace: Trace? = nil) {
        self.path = path
        self.reason = reason
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> ReferenceUnfit {
        ReferenceUnfit(path: path, reason: reason, trace: trace)
    }

    // MARK: - Private
}
