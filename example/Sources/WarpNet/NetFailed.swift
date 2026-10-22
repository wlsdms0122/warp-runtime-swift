//
//  NetFailed.swift
//  WarpNet
//

import Foundation
import Warp

// The `net` module failing: a url that does not read, or a request that
// gets no response. A rescue catches it under `net_failed`.
public struct NetFailed: RecoverableFailure {
    // MARK: - Property
    public static let type = "net_failed"

    public let message: String
    public let url: String
    public let trace: Trace?

    public var type: String { Self.type }

    public var details: Value.Dictionary { Value.Dictionary(["url": .string(url)]) }

    // MARK: - Initializer
    public init(_ message: String, url: String, trace: Trace? = nil) {
        self.message = message
        self.url = url
        self.trace = trace
    }

    // MARK: - Public
    public var description: String { message }

    // MARK: - Private
}
