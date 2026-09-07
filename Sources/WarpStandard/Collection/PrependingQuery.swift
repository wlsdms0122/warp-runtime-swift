//
//  PrependingQuery.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The elements with one more at the front.
struct PrependingQuery: Query {
    typealias Parameters = ArrayAndElement

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        // Answered in the spelling the receiver arrived in, so a compact one
        // stays compact until an element that is not a byte is put among them,
        // which `adding` reads for itself. Only the arriving element decides
        // that, so only it is looked at.
        guard let receiver = question.receiver, receiver.elements != nil else { return nil }

        return receiver.adding(question[.value], atFront: true)
    }

    // MARK: - Private
}
