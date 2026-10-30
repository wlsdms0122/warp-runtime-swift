//
//  FirstEffect.swift
//  WarpStandard
//
//  Created by JSilver on 8/22/26.
//

import Foundation
import Warp

// Runs every closure, returns the first success and asks the rest to stop.
struct FirstEffect: Effect {
    typealias Parameters = FanoutOperand

    // MARK: - Property
    private let fanout: Fanout

    // MARK: - Initializer
    init(implementing procedure: String) {
        self.fanout = Fanout(procedure)
    }

    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await fanout.first(invocation)
    }

    // MARK: - Private
}
