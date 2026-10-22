//
//  JSONFailed.swift
//  WarpJSON
//

import Foundation
import Warp

// Text handed to `JSON.parse` that is not JSON. A rescue catches it under
// `json_failed`.
public struct JSONFailed: RecoverableFailure {
    // MARK: - Property
    public static let type = "json_failed"

    public let message: String
    public let trace: Trace?

    public var type: String { Self.type }

    // MARK: - Initializer
    public init(_ message: String, trace: Trace? = nil) {
        self.message = message
        self.trace = trace
    }

    // MARK: - Public
    public var description: String { message }

    // MARK: - Private
}
