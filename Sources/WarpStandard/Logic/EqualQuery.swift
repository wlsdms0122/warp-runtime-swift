//
//  EqualQuery.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

// Whether two values are the same. Numbers compare across their
// representations, so `1` and `1.0` are one value asked about twice.
struct EqualQuery: Query {
    typealias Parameters = ComparedPair

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        .bool((question.receiver ?? .null).matches(question[.value]))
    }

    // MARK: - Private
}
