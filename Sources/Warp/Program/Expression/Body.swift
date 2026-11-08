//
//  Body.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// Statements run in order. What a procedure, a closure and each body of a
// construct are made of.
package struct Body: Sendable {
    // MARK: - Property
    package private(set) var statements: [Statement]

    // Whether every way through this body leaves. A body leaves when one of
    // its statements always leaves, because nothing after that one runs.
    var alwaysLeaves: Bool {
        statements.contains { statement in statement.expression.alwaysLeaves }
    }

    // MARK: - Initializer
    package init(_ statements: [Statement]) {
        self.statements = statements
    }

    // MARK: - Public
    package mutating func append(_ statement: Statement) {
        statements.append(statement)
    }

    // MARK: - Private
}
