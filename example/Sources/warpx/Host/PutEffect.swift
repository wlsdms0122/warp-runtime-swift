//
//  PutEffect.swift
//  warpx
//

import Foundation
import Warp

struct PutEffect: Effect {
    typealias Parameters = PutParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .string(key) = invocation[.key] else {
            throw ExecutionError("'\(invocation.selector)' keeps under a string key")
        }

        try await Store.of(invocation).put(key, invocation[.value])

        return .null
    }

    // MARK: - Private
}
