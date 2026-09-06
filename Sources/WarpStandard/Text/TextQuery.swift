//
//  TextQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The transformations of a string that take nothing, which is what makes them
// reachable from a path: `name.uppercased` supplies everything they ask for.
struct TextQuery: Query {
    enum Transform: Sendable {
        case uppercased
        case lowercased
        case trimmed
    }

    // MARK: - Property
    private let transform: Transform

    // MARK: - Initializer
    public init(_ transform: Transform) {
        self.transform = transform
    }

    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        // Not a string is not a failure here. A path that asks for the upper
        // case of a number reads as absence, the same as a field never set.
        guard case let .string(text) = question.receiver else { return nil }

        switch transform {
        case .uppercased:
            return .string(text.uppercased())

        case .lowercased:
            return .string(text.lowercased())

        case .trimmed:
            return .string(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    // MARK: - Private
}
