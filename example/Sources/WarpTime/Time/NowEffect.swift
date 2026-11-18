//
//  NowEffect.swift
//  WarpTime
//

import Foundation
import Warp

struct NowEffect: Effect {
    typealias Parameters = NoParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        .int(Int(Date().timeIntervalSince1970 * 1000))
    }

    // MARK: - Private
}
