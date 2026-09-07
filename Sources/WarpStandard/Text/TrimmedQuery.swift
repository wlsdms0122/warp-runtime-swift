//
//  TrimmedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// The text without surrounding whitespace.
struct TrimmedQuery: Query {
    typealias Parameters = StringReceiver

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        // Not a string is not a failure here. A path that asks a string word
        // of a number reads as absence, the same as a field never set.
        guard case let .string(text) = question.receiver else { return nil }

        return .string(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Private
}
