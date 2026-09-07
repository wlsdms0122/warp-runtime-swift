//
//  DropFirstQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The elements after the first. Dropping from an array that has nothing left
// answers the empty array rather than failing: taking none of nothing is
// nothing. Said by position, because this never has to look at an element,
// so a compact spelling is trimmed as what it holds.
struct DropFirstQuery: Query {
    typealias Parameters = ArrayReceiver

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, so bytes are read where an array is.
        guard let receiver = question.receiver, let elements = receiver.elements else { return nil }

        return receiver.elements(at: (0 ..< elements.count).dropFirst())
    }

    // MARK: - Private
}
