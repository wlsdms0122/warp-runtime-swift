//
//  PostEffect.swift
//  WarpNet
//

import Foundation
import Warp

struct PostEffect: Effect {
    typealias Parameters = PostParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .string(body) = invocation[.body] else {
            throw ExecutionError("'\(invocation.selector)' sends a body as a string, and \(invocation[.body].nominal) arrived")
        }

        return try await Request(invocation, method: "POST", url: .url, headers: .headers, body: body).send()
    }

    // MARK: - Private
}
