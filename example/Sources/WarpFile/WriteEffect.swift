//
//  WriteEffect.swift
//  WarpFile
//

import Foundation
import Warp

struct WriteEffect: Effect {
    typealias Parameters = WriteParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        let (url, path) = try Lent.file(invocation, at: .path)

        guard case let .string(text) = invocation[.text] else {
            throw ExecutionError("'\(invocation.selector)' writes text, and \(invocation[.text].nominal) arrived")
        }

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw FileFailed("'\(path)' does not write: \(error.localizedDescription)", path: path)
        }

        return .null
    }

    // MARK: - Private
}
