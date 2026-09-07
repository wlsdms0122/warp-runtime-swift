//
//  OrQuery.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

// Whether one link answers true, asked until one does.
struct OrQuery: Query {
    typealias Parameters = ChainReceiver

    // MARK: - Property
    private let connective = Connective(.or)

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Parameters>) throws -> Value? {
        try connective.answer(question.receiver, asking: question)
    }

    // MARK: - Private
}
