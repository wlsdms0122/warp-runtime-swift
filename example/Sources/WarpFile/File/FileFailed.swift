//
//  FileFailed.swift
//  WarpFile
//

import Foundation
import Warp

// The `file` module failing: a path leading out of the lent directory, or the
// file system refusing. A catch takes it under `file_failed`.
public struct FileFailed: RecoverableFailure {
    // MARK: - Property
    public static let type = "file_failed"

    public let message: String
    public let path: String
    public let trace: Trace?

    public var type: String { Self.type }

    public var details: Value.Dictionary { Value.Dictionary(["path": .string(path)]) }

    // MARK: - Initializer
    public init(_ message: String, path: String, trace: Trace? = nil) {
        self.message = message
        self.path = path
        self.trace = trace
    }

    // MARK: - Public
    public var description: String { message }

    // MARK: - Private
}
