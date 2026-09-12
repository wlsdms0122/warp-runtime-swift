//
//  UnbroughtEffect.swift
//  Warp
//
//  Created by JSilver on 9/10/26.
//

import Foundation

// The stand-in for an effect whose code a compile was not handed. The other
// door of `UnbroughtProcedure`.
struct UnbroughtEffect: Effect {
    typealias Parameters = NoParameters

    // MARK: - Property
    let label: Name

    // MARK: - Initializer
    init(_ label: Name) {
        self.label = label
    }

    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        throw UnbroughtProcedure.refusal(label)
    }

    // MARK: - Private
}
