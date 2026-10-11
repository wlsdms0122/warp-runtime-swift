//
//  TypeNamespace.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// The type namespace of a list of documents: every type and contract they
// declare, each at the place it was written, and what they claim about the
// names in it, beside what the language declares itself: the contract a
// map's key answers, which asks nothing, and its claims about the types the
// language names that answer it.
//
// Types and contracts share the namespace, so no name in it is both and none
// is declared twice. Each space is gathered whole before the spaces are held
// against each other, so what is refused does not depend on the order the
// documents were listed in.
struct TypeNamespace {
    // MARK: - Property
    let types: [Name: Placed<TypeExpression>]
    let contracts: [Name: Placed<[Name: ContractProcedure]>]

    // What each document said one of its types, or another document's,
    // answers. A list, since a claim declares no name for a table to be keyed
    // by. A pair two documents claim is one claim: a claim holds nothing but
    // the pair, so the second says what the first said.
    let claims: [Placed<Claim>]

    // The types the language names that answer `Hashable`: every kind a
    // value is but a procedure, which is the same as no value.
    static let hashable: [Name] = [
        TypeSpelling.null,
        TypeSpelling.bool,
        TypeSpelling.int,
        TypeSpelling.double,
        TypeSpelling.string,
        TypeSpelling.array,
        TypeSpelling.dictionary
    ]

    // MARK: - Initializer
    init(_ documents: [any Declaring]) throws {
        // The language's own stand as no document's, ahead of every one.
        let language = Place.Document.assembled

        var types: [Name: Placed<TypeExpression>] = [:]
        var contracts: [Name: Placed<[Name: ContractProcedure]>] = [
            TypeSpelling.hashable: Placed([:], at: .contract(TypeSpelling.hashable.spelling, in: language), of: -1)
        ]

        for (handed, held) in documents.enumerated() {
            for (name, type) in held.types.sorted(by: { $0.key < $1.key }) {
                let declaration = Placed(type, at: .type(name.spelling, in: held.document), of: handed)

                // Read before written. Written first, the entry that says what
                // this collides with is the one this call overwrote.
                if let first = types[name] {
                    throw BuildError.declaredTwice(name, by: first.spelled, and: declaration.spelled, at: declaration.place)
                }

                types[name] = declaration
            }
        }

        for (handed, held) in documents.enumerated() {
            for (name, procedures) in held.contracts.sorted(by: { $0.key < $1.key }) {
                let declaration = Placed(
                    procedures,
                    at: .contract(name.spelling, in: held.document),
                    of: handed
                )

                if let declared = types[name] {
                    throw BuildError(
                        "'\(name)' is declared as both a type and a contract in"
                            + " this link, as a type by \(declared.spelled) and as a"
                            + " contract by \(declaration.spelled). One name cannot"
                            + " stand for a type and a contract at once",
                        at: declaration.place
                    )
                }

                if let first = contracts[name] {
                    throw BuildError.declaredTwice(name, by: first.spelled, and: declaration.spelled, at: declaration.place)
                }

                contracts[name] = declaration
            }
        }

        var claims: [Placed<Claim>] = Self.hashable.map { type in
            Placed(Claim(type: type, contract: TypeSpelling.hashable), at: .satisfies(type.spelling, in: language), of: -1)
        }
        var claimed = Set(claims.map(\.held))

        for (handed, held) in documents.enumerated() {
            for (type, contracts) in held.claims.sorted(by: { $0.key < $1.key }) {
                for contract in contracts.sorted() {
                    let claim = Claim(type: type, contract: contract)

                    guard claimed.insert(claim).inserted else { continue }

                    claims.append(
                        Placed(
                            claim,
                            at: .satisfies(type.spelling, in: held.document),
                            of: handed
                        )
                    )
                }
            }
        }

        self.types = types
        self.contracts = contracts
        self.claims = claims
    }

    // MARK: - Public
    // MARK: - Private
}
