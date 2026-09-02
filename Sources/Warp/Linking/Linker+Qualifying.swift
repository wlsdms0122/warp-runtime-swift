//
//  Linker+Qualifying.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

// Type and constraint names carry their module the way procedure names do: a
// module named `m` declaring `T` declares `m.T`, and a mention is that
// spelling, written out. The standard bundles write their shared vocabulary
// so (`std.Numeric`), and a document declaring a bare `Numeric` of its own
// declares a different name.
extension Linker {
    // A declaration's place together with where the caller put the module that
    // wrote it. The position is what tells two documents apart when neither was
    // read from anything, since a module a caller built has no identity and two
    // of them may declare into one namespace or into none.
    struct Declaration {
        let place: Place
        let origin: Int

        var spelled: String { place.document.spelled(at: origin) }
    }

    // The two spaces gathered whole, here and nowhere else, so the uniqueness
    // this pass refuses on is the same fact the tables are built from. A mention nothing declares is refused by the judgment that owns
    // undeclared names, which says where the mention lives.
    func qualified(_ modules: [Module]) throws -> (
        types: [String: Declared<TypeExpression>],
        constraints: [String: Declared<[TypeExpression]>]
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
        var typePlaces: [String: Declaration] = [:]
        var constraintPlaces: [String: Declaration] = [:]

        for (origin, module) in modules.enumerated() {
            for name in module.types.keys.sorted() {
                let qualified = module.qualified(name)
                let declaration = Declaration(place: .type(name, in: .of(module)), origin: origin)

                // Read before written. Written first, the entry that says what
                // this collides with is the one this call overwrote.
                if let first = typePlaces[qualified] {
                    throw LinkError(
                        "type '\(qualified)' is declared more than once in this link — by"
                            + " \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                typePlaces[qualified] = declaration
            }
        }

        for (origin, module) in modules.enumerated() {
            for name in module.constraints.keys.sorted() {
                let qualified = module.qualified(name)
                let declaration = Declaration(
                    place: .constraint(name, in: .of(module)),
                    origin: origin
                )

                if let declared = typePlaces[qualified] {
                    throw LinkError(
                        "'\(qualified)' is declared as both a type and a constraint in"
                            + " this link — as a type by \(declared.spelled) and as a"
                            + " constraint by \(declaration.spelled) — one name cannot"
                            + " stand for a shape and a membership at once",
                        at: declaration.place
                    )
                }

                if let first = constraintPlaces[qualified] {
                    throw LinkError(
                        "constraint '\(qualified)' is declared more than once in this"
                            + " link — by \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                constraintPlaces[qualified] = declaration
            }
        }

        // Uniqueness was refused above, so this only gathers, under the
        // joined name every later reading uses.
        var declaredTypes: [String: Declared<TypeExpression>] = [:]
        var declaredConstraints: [String: Declared<[TypeExpression]>] = [:]

        for module in modules {
            for (name, type) in module.types {
                let qualified = module.qualified(name)

                // The place was gathered above, under the same joined name and
                // from the same declaration, so this cannot miss — and if the
                // two ever came apart, the crash says so where a `nil` place
                // would have gone out looking like a refusal with nowhere to be.
                declaredTypes[qualified] = Declared(type, at: typePlaces[qualified]!.place)
            }

            for (name, members) in module.constraints {
                let qualified = module.qualified(name)

                declaredConstraints[qualified] = Declared(
                    members,
                    at: constraintPlaces[qualified]!.place
                )
            }
        }

        return (declaredTypes, declaredConstraints)
    }
}

// Named across the link. Reachable past this file because a refusal keyed by
// what the link calls a declaration has to be walked back to what the document
// calls it, and this is the joining that has to be undone.
extension Module {
    func qualified(_ name: String) -> String {
        Draft.qualified(name, in: namespace)
    }
}
