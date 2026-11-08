//
//  FailEffect.swift
//  WarpTestSupport
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// Fails on demand, so a test can ask what the language does with a failure
// without needing a world to fail in.
public struct FailEffect: Effect {
    public enum Parameters: Int, ParameterSet {
        case recoverable

        // MARK: - Property
        public var declared: Parameter { Parameter(name: "recoverable", type: .optional(.bool)) }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func run(_ invocation: Invocation<Self>) throws -> Value {
        guard invocation[.recoverable] == .bool(true) else {
            throw TestFatalError()
        }

        throw TestRecoverableFailure()
    }

    // MARK: - Private
}
