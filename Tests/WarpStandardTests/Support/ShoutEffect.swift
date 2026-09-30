//
//  ShoutEffect.swift
//  WarpStandardTests
//
//  Created by JSilver on 9/27/26.
//

import Foundation
import Warp
import WarpStandard

struct ShoutEffect: Effect {
    enum Parameters: Int, ParameterSet {
        case text

        // MARK: - Property
        var declared: Parameter { Parameter(name: "text", type: .string) }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) throws -> Value {
        .string(invocation.string(.text)?.uppercased() ?? "")
    }

    // MARK: - Private
}
