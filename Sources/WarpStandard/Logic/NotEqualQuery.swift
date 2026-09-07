//
//  NotEqualQuery.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

// Whether two values differ, by the same reading `equal` uses.
struct NotEqualQuery: Query {
    typealias Parameters = ComparedPair

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        .bool(!(question.receiver ?? .null).matches(question[.value]))
    }

    // MARK: - Private
}
