//
//  Block.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Statements run in order, then one expression answers.
//
// A block with no result answers nothing: the answer is the expression the
// block names as its result, so appending a statement leaves what the block is
// worth as it was.
public struct Block: Sendable {
    // Where a block's body and its result stand, as the steps from the
    // block's own place. Every walk takes them from here, the way it takes an
    // expression's children from `Expression.Child`.
    public enum Child: Sendable {
        case body
        case result

        // MARK: - Property
        public var steps: [Place.Step] {
            switch self {
            case .body: [.part(.body)]
            case .result: [.part(.result)]
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    public let body: Body
    public let result: Expression?

    // Whether every way through this block leaves. True of the block alone,
    // validated or not: a leaving body never reaches the result, and a leaving
    // result leaves the block the body finished. (`Validator` refuses a result
    // under a leaving body as unreachable.)
    var alwaysLeaves: Bool {
        body.alwaysLeaves || result?.alwaysLeaves == true
    }

    // MARK: - Initializer
    // A result of null is no result: a document reads `result null` as
    // nothing written, so the model holds the one form either way.
    public init(body: Body, result: Expression? = nil) {
        self.body = body

        if case .literal(.null)? = result {
            self.result = nil
        } else {
            self.result = result
        }
    }

    // MARK: - Public
    // MARK: - Private
}
