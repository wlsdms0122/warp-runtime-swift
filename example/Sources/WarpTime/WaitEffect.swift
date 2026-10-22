//
//  WaitEffect.swift
//  WarpTime
//

import Foundation
import Warp

struct WaitEffect: Effect {
    typealias Parameters = WaitParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .int(milliseconds) = invocation[.milliseconds], milliseconds >= 0 else {
            throw ExecutionError("'\(invocation.selector)' waits a whole number of milliseconds, and \(invocation[.milliseconds]) arrived")
        }

        try await Task.sleep(for: .milliseconds(milliseconds))

        return .null
    }

    // MARK: - Private
}
