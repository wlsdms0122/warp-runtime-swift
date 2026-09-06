//
//  Draft.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// What a document declares, before anything has been held to the language's
// rules. A draft is not a module: it cannot be linked and cannot be run, and
// the only thing that takes one is the module's initializer, which is where the
// checking is.
//
// It exists because two questions are asked of one text and only one of them is
// about the program. What a document *is* (which is what telling one document
// from another is done on) is answered by writing it back out, and a document
// with a name nothing declares is still a document. So the writing takes a
// draft, and a text nobody can run still has a canonical form and an identity.
public struct Draft: Sendable {
    // MARK: - Property
    public let description: String?

    // What the document said it imports, and nil where it said nothing. A
    // module resolves this; here it is still only what was written.
    public let imports: Set<Name>?

    public let types: [Name: TypeExpression]
    public let constraints: [Name: [TypeExpression]]
    public let constants: [Name: Expression]

    // Names bound to boxes the document's procedures share, each holding what
    // its expression settles to when a run starts. Declared like a constant
    // and read by the same spelling; unlike a constant, a body may write one.
    public let variables: [Name: Expression]

    public let procedures: [Name: Procedure]

    // MARK: - Initializer
    public init(
        description: String? = nil,
        imports: Set<Name>? = nil,
        types: [Name: TypeExpression] = [:],
        constraints: [Name: [TypeExpression]] = [:],
        constants: [Name: Expression] = [:],
        variables: [Name: Expression] = [:],
        procedures: [Name: Procedure]
    ) {
        self.description = description
        self.imports = imports
        self.types = types
        self.constraints = constraints
        self.constants = constants
        self.variables = variables
        self.procedures = procedures
    }

    // The words this declares and does not itself declare a procedure for.
    //
    // Sent, not reached. A path reaches words too (`x.count` is one) but only
    // ones that answer without running, since that is the whole of what makes a
    // path safe to walk. So this is everything the program can do that touches
    // anything, and a caller reading it is reading the bounds of what it is
    // about to allow.
    public var sends: Set<Name> {
        // A constant is an expression, so it sends words like any other.
        // Missing them would understate what a program does.
        let held = constants.values.flatMap(\.buried)
            + variables.values.flatMap(\.buried)
            + procedures.values.flatMap { procedure in procedure.block?.buried ?? [] }

        // Its own by the spelling the link knows it as. A module names a
        // sibling the way any other module does, so what it declares is not
        // something it imports.
        let declared = Set(procedures.keys)

        return held
            .reduce(into: Set()) { sent, expression in
                guard case let .dispatch(dispatch) = expression else { return }

                sent.insert(dispatch.selector)
            }
            .subtracting(declared)
    }

    // MARK: - Private
}
