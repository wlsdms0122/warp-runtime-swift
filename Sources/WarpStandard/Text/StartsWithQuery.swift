//
//  StartsWithQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

struct StartsWithQuery: Query {
    typealias Parameters = StringPair

    // MARK: - Property

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        guard let receiver = question.receiver, receiver != .null else { return .bool(false) }

        guard case let .string(prefix) = question[.value] else {
            return .bool(false)
        }

        guard case let .string(text) = receiver else {
            throw ExecutionError("startsWith asks \(receiver.type), expected string")
        }

        return .bool(text.hasPrefix(prefix))
    }

    // MARK: - Private
}
