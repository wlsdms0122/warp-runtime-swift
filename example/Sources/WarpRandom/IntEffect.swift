//
//  IntEffect.swift
//  WarpRandom
//

import Foundation
import Warp

struct IntEffect: Effect {
    typealias Parameters = IntParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .int(under) = invocation[.under], under > 0 else {
            throw ExecutionError("'\(invocation.selector)' rolls under a positive whole number, and \(invocation[.under]) arrived")
        }

        return .int(Int.random(in: 0..<under))
    }

    // MARK: - Private
}
