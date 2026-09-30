//
//  Block.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Statements run in order, then one expression answers.
//
// A block with no result answers nothing. The alternative (the last statement's
// value) puts the answer somewhere nothing points at, so appending a statement
// changes what the block is worth and the author who appended it wrote nothing
// that says so. Naming the answer costs one line and says which line it is.
public struct Block: Sendable {
    // MARK: - Property
    public let body: Body
    public let result: Expression?

    // Whether every way through this block leaves. True of the block alone,
    // validated or not: a leaving body never reaches the result, and a leaving
    // result leaves the block the body finished. (`Validator` refuses a result
    // under a leaving body as unreachable.)
    public var alwaysLeaves: Bool {
        body.alwaysLeaves || result?.alwaysLeaves == true
    }

    // MARK: - Initializer
    // A result of null is no result: a document reads `result null` as
    // nothing written, so the model holds the one shape either way.
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
