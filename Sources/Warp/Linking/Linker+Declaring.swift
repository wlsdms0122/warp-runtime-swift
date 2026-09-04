//
//  Linker+Declaring.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

// Type and constraint names are their declared spelling, the way procedure
// names are: the standard bundles declare `std.Numeric` under that key, and a
// document declaring a bare `Numeric` of its own declares a different name.
extension Linker {
    // A declaration's place together with where the caller put the module that
    // wrote it. The position is what tells two documents apart when neither was
    // read from anything, since a module a caller built has no identity.
    struct Declaration {
        let place: Place
        let origin: Int

        var spelled: String { place.document.spelled(at: origin) }
    }

    // The two spaces gathered whole, here and nowhere else, so the uniqueness
    // this pass refuses on is the same fact the tables are built from: each
    // table is filled as its space is walked. A mention nothing declares is
    // refused by the judgment that owns undeclared names, which says where the
    // mention lives.
    func declared(in modules: [Module]) throws -> (
        types: [Name: Declared<TypeExpression>],
        constraints: [Name: Declared<[TypeExpression]>]
    ) {
        // Where each name was written, gathered here and carried with what it
        // holds. This is where both halves of the joining are in hand —
        // anywhere later has only the joined name, and taking it apart again is
        // a second copy of a rule that has to be right once.
        //
        // One table per space, and the table is what says a name is taken. A
        // set beside it saying the same thing is a second answer to one
        // question, and the two come apart exactly where it matters: a refusal
        // about a name declared twice is the one reader that needs the entry
        // the set had already accounted for.
        //
        // Each space is walked whole before the two are held against each
        // other, so what a link concludes cannot depend on the order the caller
        // happened to list the modules in.
        var typePlaces: [Name: Declaration] = [:]
        var constraintPlaces: [Name: Declaration] = [:]
        var declaredTypes: [Name: Declared<TypeExpression>] = [:]
        var declaredConstraints: [Name: Declared<[TypeExpression]>] = [:]

        for (origin, module) in modules.enumerated() {
            for (name, type) in module.types.sorted(by: { $0.key < $1.key }) {
                let declaration = Declaration(place: .type(name.spelling, in: .of(module)), origin: origin)

                // Read before written. Written first, the entry that says what
                // this collides with is the one this call overwrote.
                if let first = typePlaces[name] {
                    throw LinkError(
                        "type '\(name)' is declared more than once in this link — by"
                            + " \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                typePlaces[name] = declaration
                declaredTypes[name] = Declared(type, at: declaration.place)
            }
        }

        for (origin, module) in modules.enumerated() {
            for (name, members) in module.constraints.sorted(by: { $0.key < $1.key }) {
                let declaration = Declaration(
                    place: .constraint(name.spelling, in: .of(module)),
                    origin: origin
                )

                if let declared = typePlaces[name] {
                    throw LinkError(
                        "'\(name)' is declared as both a type and a constraint in"
                            + " this link — as a type by \(declared.spelled) and as a"
                            + " constraint by \(declaration.spelled) — one name cannot"
                            + " stand for a shape and a membership at once",
                        at: declaration.place
                    )
                }

                if let first = constraintPlaces[name] {
                    throw LinkError(
                        "constraint '\(name)' is declared more than once in this"
                            + " link — by \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                constraintPlaces[name] = declaration
                declaredConstraints[name] = Declared(members, at: declaration.place)
            }
        }

        return (declaredTypes, declaredConstraints)
    }
}
