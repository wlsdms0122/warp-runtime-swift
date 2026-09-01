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
// about the program. What a document *is* — which is what telling one document
// from another is done on — is answered by writing it back out, and a document
// with a name nothing declares is still a document. So the writing takes a
// draft, and a text nobody can run still has a canonical form and an identity.
public struct Draft: Sendable {
    // MARK: - Property
    public let namespace: String?
    public let description: String?

    // What the document said it imports, and nil where it said nothing. A
    // module resolves this; here it is still only what was written.
    public let imports: Set<String>?

    public let types: [String: TypeExpression]
    public let constraints: [String: [TypeExpression]]
    public let constants: [String: Expression]
    public let procedures: [String: Procedure]

    // MARK: - Initializer
    public init(
        namespace: String? = nil,
        description: String? = nil,
        imports: Set<String>? = nil,
        types: [String: TypeExpression] = [:],
        constraints: [String: [TypeExpression]] = [:],
        constants: [String: Expression] = [:],
        procedures: [String: Procedure]
    ) {
        self.namespace = namespace
        self.description = description
        self.imports = imports
        self.types = types
        self.constraints = constraints
        self.constants = constants
        self.procedures = procedures
    }

    // MARK: - Public
    // The words this declares and does not itself declare a procedure for.
    //
    // Sent, not reached. A path reaches words too — `x.count` is one — but only
    // ones that answer without running, since that is the whole of what makes a
    // path safe to walk. So this is everything the program can do that touches
    // anything, and a caller reading it is reading the bounds of what it is
    // about to allow.
    public var sends: Set<String> {
        // A constant is an expression, so it sends words like any other.
        // Missing them would understate what a program does.
        let held = constants.values.flatMap(\.buried)
            + procedures.values.flatMap { procedure in procedure.block?.buried ?? [] }

        return held
            .reduce(into: Set()) { sent, expression in
                guard case let .dispatch(dispatch) = expression else { return }

                sent.insert(dispatch.selector)
            }
            .subtracting(procedures.keys)
    }

    // MARK: - Private
}
