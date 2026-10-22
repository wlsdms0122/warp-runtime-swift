//
//  TextQuery.swift
//  WarpJSON
//

import Foundation
import Warp

struct TextQuery: Query {
    typealias Parameters = OfParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value {
        .string(try JSON.text(from: question[.of]))
    }

    // MARK: - Private
}
