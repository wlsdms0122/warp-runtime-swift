//
//  AndQuery.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

// Whether every link answers true, asked until one does not.
struct AndQuery: Query {
    typealias Parameters = ChainReceiver

    // MARK: - Property
    private let connective = Connective(.and)

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        try connective.answer(question.receiver, asking: question)
    }

    // MARK: - Private
}
