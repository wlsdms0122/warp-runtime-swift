//
//  ProcedureType.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

// What a slot asks of a procedure value: the types it is applied with, in
// position order, and what it answers. No names. A name is a declaration's or
// a closure's, read by its body; a value is applied by position, so two
// closures that name their parameters differently are one type where the
// types agree.
public struct ProcedureType: Sendable, Equatable {
    // MARK: - Property
    // Each parameter's type, marks included, since `inout`, `consuming` and
    // `borrowing` are facts about the slot a value is applied through.
    public let parameters: [TypeExpression]

    // What an application answers, or nil where nothing was declared.
    public let returns: TypeExpression?

    // MARK: - Initializer
    public init(parameters: [TypeExpression] = [], returns: TypeExpression? = nil) {
        self.parameters = parameters
        self.returns = returns
    }

    // MARK: - Public
    // MARK: - Private
}
