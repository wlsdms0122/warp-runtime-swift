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
        let file = try File(invocation, at: .path)

        guard case let .string(text) = invocation[.text] else {
            throw ExecutionError("'\(invocation.selector)' writes a string, and \(invocation[.text].nominal) arrived")
        }

        do {
            try FileManager.default.createDirectory(at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file.url, atomically: true, encoding: .utf8)
        } catch {
            throw FileFailed("'\(file.path)' does not write: \(error.localizedDescription)", path: file.path)
        }

        return .null
    }

    // MARK: - Private
}
