//
//  IssueEffect.swift
//  warpx
//

import Foundation
import Warp

struct IssueEffect: Effect {
    typealias Parameters = NoParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        let store = try Store.of(invocation)
        let id = await store.issue()

        return try Value.holding([(name: "id", value: .int(id))], named: "Host.Ticket")
    }

    // MARK: - Private
}
