//
//  FailEffect.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/27/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

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
