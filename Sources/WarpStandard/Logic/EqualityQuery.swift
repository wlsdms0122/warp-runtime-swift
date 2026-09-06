//
//  EqualityQuery.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

// Whether two values are the same, and its negation. Numbers compare across
// their representations, so `1` and `1.0` are one value asked about twice.
struct EqualityQuery: Query {
    enum Sense: Sendable {
        case same
        case different
    }

    // MARK: - Property
    private let sense: Sense

    // MARK: - Initializer
    public init(_ sense: Sense) {
        self.sense = sense
    }

    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        let matches = (question.receiver ?? .null).matches(question["value"])

        return .bool(sense == .same ? matches : !matches)
    }

    // MARK: - Private
}
