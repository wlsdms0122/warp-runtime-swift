//
//  Builder+Declaring.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

// Type, constraint and contract names are their declared spelling, the way
// procedure names are: the standard bundles declare `std.Numeric` under that
// key, and a document declaring a bare `Numeric` of its own declares a
// different name.
extension Builder {
    // The three spaces gathered whole, here and nowhere else, so the uniqueness
    // this pass refuses on is the same fact the tables are built from: each
    // table is filled as its space is walked. A mention nothing declares is
    // refused by the judgment that owns undeclared names, which says where the
    // mention lives.
    func declared(in documents: [any Declaring]) throws -> (
        types: [Name: Placed<TypeExpression>],
        constraints: [Name: Placed<[TypeExpression]>],
        contracts: [Name: Placed<[Name: Signature]>],
        claims: [Placed<Claim>]
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
        var declaredTypes: [Name: Placed<TypeExpression>] = [:]
        var declaredConstraints: [Name: Placed<[TypeExpression]>] = [:]
        var declaredContracts: [Name: Placed<[Name: Signature]>] = [:]

        for (origin, held) in documents.enumerated() {
            for (name, type) in held.types.sorted(by: { $0.key < $1.key }) {
                let declaration = Placed(type, at: .type(name.spelling, in: held.document), of: origin)

                // Read before written. Written first, the entry that says what
                // this collides with is the one this call overwrote.
                if let first = declaredTypes[name] {
                    throw BuildError(
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
                let declaration = Placed(
                    members,
                    at: .constraint(name.spelling, in: held.document),
                    of: origin
                )

                if let declared = declaredTypes[name] {
                    throw BuildError(
                        "'\(name)' is declared as both a type and a constraint in"
                            + " this link, as a type by \(declared.spelled) and as a"
                            + " constraint by \(declaration.spelled). One name cannot"
                            + " stand for a shape and a membership at once",
                        at: declaration.place
                    )
                }

                if let first = declaredConstraints[name] {
                    throw BuildError(
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
                let declaration = Placed(
                    words,
                    at: .contract(name.spelling, in: held.document),
                    of: origin
                )

                if let declared = declaredTypes[name]?.spelled ?? declaredConstraints[name]?.spelled {
                    throw BuildError(
                        "'\(name)' is declared as a contract in this link and as"
                            + " something else by \(declared). One name"
                            + " cannot stand for two of a shape, a membership and"
                            + " a contract at once",
                        at: declaration.place
                    )
                }

                if let first = declaredContracts[name] {
                    throw BuildError(
                        "contract '\(name)' is declared more than once in this"
                            + " link, by \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                guard !words.isEmpty else {
                    throw BuildError(
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
        // answers. Handed on as a list, since a claim declares no name for a
        // table to be keyed by.
        //
        // A pair two documents claim is one claim. A claim holds nothing but
        // the pair, so two of them cannot disagree, and the second says what
        // the first said.
        var claimed: Set<Claim> = []
        var claims: [Placed<Claim>] = []

        for (origin, held) in documents.enumerated() {
            for (type, contracts) in held.claiming.sorted(by: { $0.key < $1.key }) {
                for contract in contracts.sorted() {
                    let claim = Claim(type: type, contract: contract)

                    guard claimed.insert(claim).inserted else { continue }

                    claims.append(
                        Placed(
                            claim,
                            at: .satisfies(type.spelling, in: held.document),
                            of: origin
                        )
                    )
                }
            }
        }

        return (declaredTypes, declaredConstraints, declaredContracts, claims)
    }
}
