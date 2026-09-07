//
//  FirstEffect.swift
//  WarpStandard
//
//  Created by JSilver on 8/22/26.
//

import Foundation
import Warp

// Runs every closure, answers the first success and asks the rest to stop.
struct FirstEffect: Effect {
    typealias Parameters = FanoutReceiver

    // MARK: - Property
    let failing = Failing.these([ConcurrentFailed.word])

    private let fanout = Fanout("std.concurrent.first")

    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await fanout.first(invocation)
    }

    // MARK: - Private
}
