//
//  ModuleVariable.swift
//  Warp
//
//  Created by JSilver on 9/22/26.
//

import Foundation

// A module variable as a document declares it: the type it holds and what
// it starts as.
package struct ModuleVariable: Sendable {
    // MARK: - Property
    package let declared: TypeExpression
    package let start: Expression

    // MARK: - Initializer
    package init(_ start: Expression, declared: TypeExpression) {
        self.declared = declared
        self.start = start
    }

    // MARK: - Public
    // Where the start stands, given where the variable does.
    package func start(at variable: Place) -> Place {
        variable.part(.start)
    }

    // MARK: - Private
}
