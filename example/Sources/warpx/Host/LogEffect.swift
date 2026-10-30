//
//  LogEffect.swift
//  warpx
//

import Foundation
import Warp

struct LogEffect: Effect {
    typealias Parameters = LogParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await Store.of(invocation).note("\(invocation[.of])")

        return .null
    }

    // MARK: - Private
}
