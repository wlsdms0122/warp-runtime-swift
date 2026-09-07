//
//  ReversedQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The same elements in the other order, said by position, so the spelling
// they arrived in is the spelling they leave in, and a compact one is turned
// around as what it holds rather than read out as values and written back.
struct ReversedQuery: Query {
    typealias Parameters = ArrayReceiver

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, so bytes are read where an array is.
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        return receiver.elements(at: (0 ..< elements.count).reversed())
    }

    // MARK: - Private
}
