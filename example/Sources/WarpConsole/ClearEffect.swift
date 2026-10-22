//
//  ClearEffect.swift
//  WarpConsole
//

import Foundation
import Warp

struct ClearEffect: Effect {
    typealias Parameters = NoParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await Console.of(invocation).clear()

        return .null
    }

    // MARK: - Private
}
