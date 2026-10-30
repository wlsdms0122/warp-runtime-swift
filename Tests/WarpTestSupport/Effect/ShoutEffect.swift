//
//  ShoutEffect.swift
//  WarpTestSupport
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

public struct ShoutEffect: Effect {
    public enum Parameters: Int, ParameterSet {
        case text

        // MARK: - Property
        public var declared: Parameter { Parameter(name: "text", type: .string) }

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
        .string(invocation.string(.text)?.uppercased() ?? "")
    }

    // MARK: - Private
}
