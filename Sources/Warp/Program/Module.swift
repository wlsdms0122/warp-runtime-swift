//
//  Module.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What one document declares, and nothing about running.
//
// A module is not a procedure and cannot be run. It becomes runnable only when a
// linker is handed it together with the others and told which name to start
// from. Which declaration that is stays an argument to linking rather than a
// property one of them carries, so there is no marking to put on a declaration
// and no reserved name.
public struct Module: Sendable {
    // MARK: - Property
    // What the module's declarations are called across a link: a named module's
    // procedures, types and constraints are qualified by this — `std.math`
    // declaring `plus` declares `std.math.plus` — and a module without one
    // declares into the shared space under the bare names. The description is
    // metadata only.
    public let name: String?
    public let description: String?

    // Shapes this module declares. A type is a name bound to a
    // `TypeExpression`, which is the same thing a procedure is with a body in
    // place of a type — a module declares, and what it declares differs only in
    // what kind of thing the name stands for.
    public let types: [String: TypeExpression]

    // Constraints this module declares: a name bound to the types a bounded
    // parameter under that name admits. Declared the same way a type is and
    // kept apart from the types, because nothing is ever *of* a constraint —
    // it bounds `some T`, and a slot cannot declare it directly.
    public let constraints: [String: [TypeExpression]]

    // Names bound to values, settled at link and gone by run time. Private to
    // the module: a constant is read by writing its name, and a name is a scope
    // question, so exporting one would need a second namespace in path position
    // — where a qualified spelling cannot be told from drilling into a record.
    public let constants: [String: Expression]

    public let procedures: [String: Procedure]

    // Which document this was read out of, where it was read out of one.
    //
    // Nil for a module a caller built, and that is the whole of what nil means:
    // nothing was written down, so there is no text for a reader to be pointed
    // back into. It is never nil for a module that came through a reader —
    // reading is where it is worked out, from the document being read.
    //
    // Not the name. `name` is the namespace this declares into and several
    // documents may share one, since a module split across files is a thing
    // this language allows; two documents named `wallet` are two documents.
    public let identity: Identity?

    // MARK: - Initializer
    public init(
        name: String? = nil,
        description: String? = nil,
        types: [String: TypeExpression] = [:],
        constraints: [String: [TypeExpression]] = [:],
        constants: [String: Expression] = [:],
        procedures: [String: Procedure],
        identity: Identity? = nil
    ) {
        self.name = name
        self.description = description
        self.types = types
        self.constraints = constraints
        self.constants = constants
        self.procedures = procedures
        self.identity = identity
    }

    // The same module, told which document it was read out of. A reader works
    // that out from the document in front of it, which is the only place the
    // answer exists — so it is put on afterwards rather than passed inward
    // through everything that builds a module up.
    public func read(from identity: Identity) -> Module {
        Module(
            name: name,
            description: description,
            types: types,
            constraints: constraints,
            constants: constants,
            procedures: procedures,
            identity: identity
        )
    }

    // MARK: - Public
    // MARK: - Private
}
