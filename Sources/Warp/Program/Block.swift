//
//  Block.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Statements run in order, then one expression answers.
//
// A block with no result answers nothing. The alternative — the last statement's
// value — puts the answer somewhere nothing points at, so appending a statement
// changes what the block is worth and the author who appended it wrote nothing
// that says so. Naming the answer costs one line and says which line it is.
public struct Block: Sendable {
    // MARK: - Property
    public let body: [Statement]
    public let result: Expression?

    // Whether every way through this block leaves — true of the block alone,
    // validated or not: a leaving body never reaches the result, and a leaving
    // result leaves the block the body finished. (A result under a leaving
    // body is separately refused as unreachable — where a document assembles
    // the pair, and where a hand-assembled block is validated.)
    public var alwaysLeaves: Bool {
        body.alwaysLeaves || result?.alwaysLeaves == true
    }

    // MARK: - Initializer
    public init(body: [Statement], result: Expression? = nil) {
        self.body = body
        self.result = result
    }

    // MARK: - Public
    // MARK: - Private
}
