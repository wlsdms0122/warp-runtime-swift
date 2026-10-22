//
//  KeyEffect.swift
//  WarpConsole
//

import Foundation
import Warp

struct KeyEffect: Effect {
    typealias Parameters = NoParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard let key = try await Console.of(invocation).key() else { return .null }

        return .string(key)
    }

    // MARK: - Private
}
