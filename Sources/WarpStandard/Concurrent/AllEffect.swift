//
//  AllEffect.swift
//  WarpStandard
//
//  Created by JSilver on 8/22/26.
//

import Foundation
import Warp

// Runs every closure and answers every answer. A record's under its keys, an
// array's in its order.
struct AllEffect: Effect {
    typealias Parameters = FanoutOperand

    // MARK: - Property
    // Every recoverable failure a piece raises is gathered into one.
    let failing = Failing.these([ConcurrentFailed.type])

    private let fanout: Fanout

    // MARK: - Initializer
    init(answering procedure: String) {
        self.fanout = Fanout(procedure)
    }

    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await fanout.all(invocation)
    }

    // MARK: - Private
}
