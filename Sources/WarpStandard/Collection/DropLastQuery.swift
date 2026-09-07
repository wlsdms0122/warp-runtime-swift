//
//  DropLastQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The elements before the last, the way `dropFirst` reads them.
struct DropLastQuery: Query {
    typealias Parameters = ArrayReceiver

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, so bytes are read where an array is.
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        return receiver.elements(at: (0 ..< elements.count).dropLast())
    }

    // MARK: - Private
}
