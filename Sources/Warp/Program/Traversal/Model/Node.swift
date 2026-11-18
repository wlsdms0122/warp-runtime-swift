//
//  Node.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// What a walk finds: a statement, or an expression. A stage keeps the one it is
// after and the walk keeps neither. What is held where is a fact of the
// language, and which of it matters is the stage's own question.
enum Node: Sendable {
    case statement(Statement)
    case expression(Expression)
}
