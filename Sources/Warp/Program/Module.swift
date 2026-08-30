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
    public private(set) var name: String?
    public private(set) var description: String?

    // Shapes this module declares. A type is a name bound to a
    // `TypeExpression`, which is the same thing a procedure is with a body in
    // place of a type — a module declares, and what it declares differs only in
    // what kind of thing the name stands for.
    public private(set) var types: [String: TypeExpression]

    // Constraints this module declares: a name bound to the types a bounded
    // parameter under that name admits. Declared the same way a type is and
    // kept apart from the types, because nothing is ever *of* a constraint —
    // it bounds `some T`, and a slot cannot declare it directly.
    public private(set) var constraints: [String: [TypeExpression]]

    // Names bound to values, settled at link and gone by run time. Private to
    // the module: a constant is read by writing its name, and a name is a scope
    // question, so exporting one would need a second namespace in path position
    // — where a qualified spelling cannot be told from drilling into a record.
    public private(set) var constants: [String: Expression]

    public private(set) var procedures: [String: Procedure]

    // Which document this was read out of, where it was read out of one.
    //
    // Nil where nobody said which document this came out of: a module a caller
    // built has no text under it at all, and a reader is told which text it is
    // reading rather than working it out — deriving one means writing the
    // document back to its canonical bytes, which is not what reading a
    // document is for.
    //
    // Not the name. `name` is the namespace this declares into and several
    // documents may share one, since a module split across files is a thing
    // this language allows; two documents named `wallet` are two documents.
    public private(set) var identity: Identity?

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

    // The same module with something changed.
    //
    // A copy of the whole with the named parts written over, rather than a new
    // module built field by field: a copy that lists what it carries keeps only
    // what somebody remembered to list, and a field left off is not a compiler
    // error but a fact quietly going missing. Nothing here enumerates, so a
    // field added to a module is carried through by every copy without this
    // having to be told about it.
    func replacing(
        types: [String: TypeExpression]? = nil,
        constraints: [String: [TypeExpression]]? = nil,
        constants: [String: Expression]? = nil,
        procedures: [String: Procedure]? = nil,
        identity: Identity? = nil
    ) -> Module {
        var copy = self

        if let types { copy.types = types }
        if let constraints { copy.constraints = constraints }
        if let constants { copy.constants = constants }
        if let procedures { copy.procedures = procedures }
        if let identity { copy.identity = identity }

        return copy
    }

    // The same module, told which document it was read out of. A reader is told
    // that from outside, since working it out means writing the document back
    // to its canonical bytes — so it is put on afterwards rather than passed
    // inward through everything that builds a module up.
    public func read(from identity: Identity) -> Module {
        replacing(identity: identity)
    }

    // MARK: - Public
    // MARK: - Private
}
