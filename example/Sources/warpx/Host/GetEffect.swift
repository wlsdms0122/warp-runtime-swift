//
//  GetEffect.swift
//  warpx
//

import Foundation
import Warp

struct GetEffect: Effect {
    typealias Parameters = GetParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .string(key) = invocation[.key] else {
            throw ExecutionError("'\(invocation.selector)' reads under a string key")
        }

        return try await Store.of(invocation).get(key)
    }

    // MARK: - Private
}
