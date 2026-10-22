//
//  GetEffect.swift
//  WarpNet
//

import Foundation
import Warp

struct GetEffect: Effect {
    typealias Parameters = GetParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await Request.send(invocation, method: "GET", url: .url, headers: .headers, body: nil)
    }

    // MARK: - Private
}
