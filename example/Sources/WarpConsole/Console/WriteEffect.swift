//
//  WriteEffect.swift
//  WarpConsole
//

import Foundation
import Warp

struct WriteEffect: Effect {
    typealias Parameters = WriteParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .string(text) = invocation[.text] else {
            throw ExecutionError("'\(invocation.selector)' writes a string, and \(invocation[.text].nominal) arrived")
        }

        try await Console.of(invocation).write(text)

        return .null
    }

    // MARK: - Private
}
