//
//  FirstQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The first element, or nothing. An empty array has no first, and having
// none is absence rather than failure. The same answer a missing field
// gives.
struct FirstQuery: Query {
    typealias Parameters = ArrayReceiver

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, so bytes are read where an array is.
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        return elements.first
    }

    // MARK: - Private
}
