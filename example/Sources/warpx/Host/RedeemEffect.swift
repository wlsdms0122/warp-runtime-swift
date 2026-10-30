//
//  RedeemEffect.swift
//  warpx
//

import Foundation
import Warp

struct RedeemEffect: Effect {
    typealias Parameters = RedeemParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .struct(ticket) = invocation[.of], case let .int(id) = ticket["id"] else {
            throw ExecutionError("'\(invocation.selector)' redeems a ticket, and \(invocation[.of]) arrived")
        }

        let store = try Store.of(invocation)

        guard await store.redeem(id) else {
            throw ExecutionError("'\(invocation.selector)' redeems ticket \(id), which is not open")
        }

        await store.note("redeemed \(id)")

        return .int(id)
    }

    // MARK: - Private
}
