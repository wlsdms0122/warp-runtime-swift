//
//  ModuleVariable.swift
//  Warp
//
//  Created by JSilver on 9/22/26.
//

import Foundation

// A module variable as a document declares it: what it starts as, and what
// it holds where the document says. A variable that says nothing holds the
// type its start settles to.
public struct ModuleVariable: Sendable {
    // MARK: - Property
    public let declared: TypeExpression?
    public let start: Expression

    // MARK: - Initializer
    public init(_ start: Expression, declared: TypeExpression? = nil) {
        self.declared = declared
        self.start = start
    }

    // MARK: - Public
    // MARK: - Private
}
