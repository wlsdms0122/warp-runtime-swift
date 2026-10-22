//
//  ProcessFailed.swift
//  WarpProcess
//

import Foundation
import Warp

// The `process` module failing: a command that cannot be started. A command
// that starts and exits with a status is not a failure; the status is the
// program's to judge. A rescue catches this under `process_failed`.
public struct ProcessFailed: RecoverableFailure {
    // MARK: - Property
    public static let type = "process_failed"

    public let message: String
    public let command: String
    public let trace: Trace?

    public var type: String { Self.type }

    public var details: Value.Dictionary { Value.Dictionary(["command": .string(command)]) }

    // MARK: - Initializer
    public init(_ message: String, command: String, trace: Trace? = nil) {
        self.message = message
        self.command = command
        self.trace = trace
    }

    // MARK: - Public
    public var description: String { message }

    // MARK: - Private
}
