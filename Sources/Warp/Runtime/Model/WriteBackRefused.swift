//
//  WriteBackRefused.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A box handed for a path into a variable could not be written back along
// that path when the call ended. The link judged the path and the run read
// its positions before the call, so this is a box whose surroundings changed
// under it: a fault of the run, and not a failure an attempt catches.
public struct WriteBackRefused: WarpError {
    // MARK: - Property
    public let path: [PathSegment]
    public let selector: String
    public let refusal: any Error
    public let trace: Trace?

    public var message: String {
        "writing '\(path.rendered)' back after '\(selector)' refused: \(refusal)"
    }

    // MARK: - Initializer
    init(path: [PathSegment], selector: String, refusal: any Error, trace: Trace? = nil) {
        self.path = path
        self.selector = selector
        self.refusal = refusal
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> WriteBackRefused {
        WriteBackRefused(path: path, selector: selector, refusal: refusal, trace: trace)
    }

    // MARK: - Private
}
