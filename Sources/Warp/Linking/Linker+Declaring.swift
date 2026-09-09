//
//  Linker+Declaring.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

// Type, constraint and contract names are their declared spelling, the way
// procedure names are: the standard bundles declare `std.Numeric` under that
// key, and a document declaring a bare `Numeric` of its own declares a
// different name.
extension Linker {
    // The three spaces gathered whole, here and nowhere else, so the uniqueness
    // this pass refuses on is the same fact the tables are built from: each
    // table is filled as its space is walked. A mention nothing declares is
    // refused by the judgment that owns undeclared names, which says where the
    // mention lives.
    func declared(in documents: [any Declaring]) throws -> (
        types: [Name: Declared<TypeExpression>],
        constraints: [Name: Declared<[TypeExpression]>],
        contracts: [Name: Declared<[Name: Signature]>],
        claims: [Declared<Claim>]
    ) {
        // Where each name was written, gathered here and carried with what it
        // holds. This is where both halves of the joining are in hand. Anywhere
        // later has only the joined name, and taking it apart again is a second
        // copy of a rule that has to be right once.
        //
        // One table per space, and the table is what says a name is taken. A
        // second table beside it saying the same thing is a second answer to
        // one question.
        //
        // Each space is walked whole before the two are held against each
        // other, so what a link concludes cannot depend on the order the caller
        // happened to list the documents in.
        var declaredTypes: [Name: Declared<TypeExpression>] = [:]
        var declaredConstraints: [Name: Declared<[TypeExpression]>] = [:]
        var declaredContracts: [Name: Declared<[Name: Signature]>] = [:]

        for (origin, held) in documents.enumerated() {
            for (name, type) in held.types.sorted(by: { $0.key < $1.key }) {
                let declaration = Declared(type, at: .type(name.spelling, in: held.document), of: origin)

                // Read before written. Written first, the entry that says what
                // this collides with is the one this call overwrote.
                if let first = declaredTypes[name] {
                    throw LinkError(
                        "type '\(name)' is declared more than once in this link, by"
                            + " \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                declaredTypes[name] = declaration
            }
        }

        for (origin, held) in documents.enumerated() {
            for (name, members) in held.constraints.sorted(by: { $0.key < $1.key }) {
                let declaration = Declared(
                    members,
                    at: .constraint(name.spelling, in: held.document),
                    of: origin
                )

                if let declared = declaredTypes[name] {
                    throw LinkError(
                        "'\(name)' is declared as both a type and a constraint in"
                            + " this link, as a type by \(declared.spelled) and as a"
                            + " constraint by \(declaration.spelled). One name cannot"
                            + " stand for a shape and a membership at once",
                        at: declaration.place
                    )
                }

                if let first = declaredConstraints[name] {
                    throw LinkError(
                        "constraint '\(name)' is declared more than once in this"
                            + " link, by \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                declaredConstraints[name] = declaration
            }
        }

        for (origin, held) in documents.enumerated() {
            for (name, words) in held.contracts.sorted(by: { $0.key < $1.key }) {
                let declaration = Declared(
                    words,
                    at: .contract(name.spelling, in: held.document),
                    of: origin
                )

                if let declared = declaredTypes[name]?.spelled ?? declaredConstraints[name]?.spelled {
                    throw LinkError(
                        "'\(name)' is declared as a contract in this link and as"
                            + " something else by \(declared). One name"
                            + " cannot stand for two of a shape, a membership and"
                            + " a contract at once",
                        at: declaration.place
                    )
                }

                if let first = declaredContracts[name] {
                    throw LinkError(
                        "contract '\(name)' is declared more than once in this"
                            + " link, by \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                guard !words.isEmpty else {
                    throw LinkError(
                        "asks nothing, so every type satisfies it. A contract is"
                            + " the words a value answers, and one with no words"
                            + " says nothing a slot could lean on",
                        at: declaration.place
                    )
                }

                declaredContracts[name] = declaration
            }
        }

        // What each document said one of its types, or another document's,
        // answers. Gathered here with the rest so a pair two documents claim
        // is refused where every other doubled declaration is, and handed on
        // as a list, since a claim declares no name for a table to be keyed
        // by.
        var claimed: [Name: [Name: Declared<Claim>]] = [:]
        var claims: [Declared<Claim>] = []

        for (origin, held) in documents.enumerated() {
            for (type, contracts) in held.satisfying.sorted(by: { $0.key < $1.key }) {
                for contract in contracts.sorted() {
                    let declaration = Declared(
                        Claim(type: type, contract: contract),
                        at: .satisfies(type.spelling, in: held.document),
                        of: origin
                    )

                    if let first = claimed[type]?[contract] {
                        throw LinkError(
                            "'\(type)' is said to answer '\(contract)' by"
                                + " \(first.spelled) and by \(declaration.spelled)."
                                + " One type answers one contract once",
                            at: declaration.place
                        )
                    }

                    claimed[type, default: [:]][contract] = declaration

                    claims.append(declaration)
                }
            }
        }

        return (declaredTypes, declaredConstraints, declaredContracts, claims)
    }
}
