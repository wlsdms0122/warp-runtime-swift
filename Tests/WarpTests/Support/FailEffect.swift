//
//  FailEffect.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
@testable import Warp

// Fails on demand, so a test can ask what the language does with a failure
// without needing a world to fail in.
struct FailEffect: Effect {
    enum Parameters: Int, ParameterSet {
        case recoverable

        // MARK: - Property
        var declared: Parameter { Parameter(name: "recoverable", type: .nullable(.bool)) }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    let failing = Failing.these([TestRecoverableFailure.type])

    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) throws -> Value {
        guard invocation[.recoverable] == .bool(true) else {
            throw TestFatalError()
        }

        throw TestRecoverableFailure()
    }

    // MARK: - Private
}
