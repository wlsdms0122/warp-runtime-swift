//
//  TypeNamespace.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// The type namespace of a list of documents: every type, membership and
// contract they declare, each at the place it was written, and what they claim
// about the names in it.
//
// Types, memberships and contracts share the namespace, so no name in it is
// two of them and none is declared twice. Each space is gathered whole before
// the spaces are held against each other, so what is refused does not depend
// on the order the documents were listed in.
struct TypeNamespace {
    // MARK: - Property
    let types: [Name: Placed<TypeExpression>]
    let constraints: [Name: Placed<[TypeExpression]>]
    let contracts: [Name: Placed<[Name: ContractProcedure]>]

    // What each document said one of its types, or another document's,
    // answers. A list, since a claim declares no name for a table to be keyed
    // by. A pair two documents claim is one claim: a claim holds nothing but
    // the pair, so the second says what the first said.
    let claims: [Placed<Claim>]

    // MARK: - Initializer
    init(_ documents: [any Declaring]) throws {
        var types: [Name: Placed<TypeExpression>] = [:]
        var constraints: [Name: Placed<[TypeExpression]>] = [:]
        var contracts: [Name: Placed<[Name: ContractProcedure]>] = [:]

        for (origin, held) in documents.enumerated() {
            for (name, type) in held.types.sorted(by: { $0.key < $1.key }) {
                let declaration = Placed(type, at: .type(name.spelling, in: held.document), of: origin)

                // Read before written. Written first, the entry that says what
                // this collides with is the one this call overwrote.
                if let first = types[name] {
                    throw BuildError(
                        "type '\(name)' is declared more than once in this link, by"
                            + " \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                types[name] = declaration
            }
        }

        for (origin, held) in documents.enumerated() {
            for (name, members) in held.constraints.sorted(by: { $0.key < $1.key }) {
                let declaration = Placed(
                    members,
                    at: .constraint(name.spelling, in: held.document),
                    of: origin
                )

                if let declared = types[name] {
                    throw BuildError(
                        "'\(name)' is declared as both a type and a constraint in"
                            + " this link, as a type by \(declared.spelled) and as a"
                            + " constraint by \(declaration.spelled). One name cannot"
                            + " stand for a type and a membership at once",
                        at: declaration.place
                    )
                }

                if let first = constraints[name] {
                    throw BuildError(
                        "constraint '\(name)' is declared more than once in this"
                            + " link, by \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                constraints[name] = declaration
            }
        }

        for (origin, held) in documents.enumerated() {
            for (name, procedures) in held.contracts.sorted(by: { $0.key < $1.key }) {
                let declaration = Placed(
                    procedures,
                    at: .contract(name.spelling, in: held.document),
                    of: origin
                )

                if let declared = types[name]?.spelled ?? constraints[name]?.spelled {
                    throw BuildError(
                        "'\(name)' is declared as a contract in this link and as"
                            + " something else by \(declared). One name"
                            + " cannot be a type, a membership and a contract"
                            + " at once",
                        at: declaration.place
                    )
                }

                if let first = contracts[name] {
                    throw BuildError(
                        "contract '\(name)' is declared more than once in this"
                            + " link, by \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                contracts[name] = declaration
            }
        }

        var claimed: Set<Claim> = []
        var claims: [Placed<Claim>] = []

        for (origin, held) in documents.enumerated() {
            for (type, contracts) in held.claims.sorted(by: { $0.key < $1.key }) {
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

        self.types = types
        self.constraints = constraints
        self.contracts = contracts
        self.claims = claims
    }

    // MARK: - Public
    // MARK: - Private
}
