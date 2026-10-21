//
//  TypeNamespace.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// The type namespace of a list of documents: every type and contract they
// declare, each at the place it was written, and what they claim about the
// names in it, beside what the language declares itself, the `Prelude`.
//
// Types and contracts share the namespace, so no name in it is both and none
// is declared twice. Each space is gathered whole before the spaces are held
// against each other, so what is refused does not depend on the order the
// documents were listed in.
struct TypeNamespace {
    // MARK: - Property
    let types: [Name: Placed<TypeDeclaration>]
    let contracts: [Name: Placed<Contract>]

    // What each document said one of its types, or another document's,
    // answers, each where it was written. A list, since a claim declares no
    // name for a table to be keyed by. A claim two documents write about one
    // pair is one claim where the heads take the same values, which the
    // build holds where the claims a document stands on are gathered.
    let claims: [Placed<Claim>]

    // Every procedure a document gave a type, by the spelling a call writes,
    // beside where the host put the document giving it: what may answer a
    // contract's procedure for that type, for a claim standing on that
    // document.
    let members: [Name: Int]

    // Every type a document gave a type under a name, by the spelling the
    // member takes, `App.Box.Item`, where the document gave it: one each,
    // whichever document gave it. What answers a contract's type for the
    // type, for a claim standing on that document.
    let typeMembers: [Name: Placed<TypeMember>]

    // Each head a document gave members under, where the document gave them.
    // Its type is held the way the type a claim is about is held, whatever
    // the document gave it.
    let extended: [Placed<Head>]

    // MARK: - Initializer
    init(_ documents: [any Declaring]) throws {
        // The language's own stand as no document's, ahead of every one.
        var types = Prelude.types.reduce(into: [Name: Placed<TypeDeclaration>]()) { types, declared in
            types[declared.key] = Placed(
                declared.value,
                at: .type(declared.key.spelling, in: Prelude.document),
                of: Prelude.handed
            )
        }
        var contracts = Prelude.contracts.reduce(
            into: [Name: Placed<Contract>]()
        ) { contracts, declared in
            contracts[declared.key] = Placed(
                declared.value,
                at: .contract(declared.key.spelling, in: Prelude.document),
                of: Prelude.handed
            )
        }

        for (handed, held) in documents.enumerated() {
            for (name, type) in held.types.sorted(by: { $0.key < $1.key }) {
                let declaration = Placed(type, at: .type(name.spelling, in: held.document), of: handed)

                // Read before written. Written first, the entry that says what
                // this collides with is the one this call overwrote. The only
                // contracts gathered yet are the language's.
                if let first = types[name] {
                    throw BuildError.declaredTwice(
                        name,
                        by: first.spelled,
                        and: declaration.spelled,
                        at: declaration.place
                    )
                }

                if let contract = contracts[name] {
                    throw BuildError.declaredAsBoth(
                        name,
                        type: declaration.spelled,
                        contract: contract.spelled,
                        at: declaration.place
                    )
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
                    throw BuildError.declaredAsBoth(
                        name,
                        type: declared.spelled,
                        contract: declaration.spelled,
                        at: declaration.place
                    )
                }

                if let first = contracts[name] {
                    throw BuildError.declaredTwice(
                        name,
                        by: first.spelled,
                        and: declaration.spelled,
                        at: declaration.place
                    )
                }

                contracts[name] = declaration
            }
        }

        var claims: [Placed<Claim>] = Prelude.claims.sorted { $0.key < $1.key }.flatMap { type, contracts in
            contracts.sorted().map { contract in
                Placed(
                    Claim(head: Head(type), contract: contract),
                    at: .satisfies(Head(type), in: Prelude.document),
                    of: Prelude.handed
                )
            }
        }
        let language = Set(claims.map(\.held))

        // Every document's claims, the same claim made by two documents
        // standing twice: each is judged where it is written, and which of
        // them a document stands on is its reach. One type answering a
        // contract one way is held where the claims are gathered for asking.
        for (handed, held) in documents.enumerated() {
            for (head, contracts) in held.claims.sorted(by: { $0.key < $1.key }) {
                for contract in contracts.sorted() {
                    let claim = Placed(
                        Claim(head: head, contract: contract),
                        at: .satisfies(head, in: held.document),
                        of: handed
                    )

                    guard !language.contains(claim.held) else { continue }

                    claims.append(claim)
                }
            }
        }

        self.types = types
        self.contracts = contracts
        self.claims = claims
        self.members = documents.enumerated().reduce(into: [:]) { members, document in
            for (head, names) in document.element.members {
                for member in names {
                    members[member.spelled(under: head.type)] = document.offset
                }
            }
        }
        // A type member is one name with one declarer, as a member is: two
        // documents giving one type a type under one name say two things
        // where a type gives one.
        var typeMembers: [Name: Placed<TypeMember>] = [:]

        for (handed, held) in documents.enumerated() {
            for member in TypeMember.listed(held.typeMembers) {
                let given = Placed(member, at: .typeMember(member, in: held.document), of: handed)

                if let first = typeMembers[member.spelling] {
                    throw BuildError.declaredTwice(
                        member.spelling,
                        by: first.spelled,
                        and: given.spelled,
                        at: given.place
                    )
                }

                typeMembers[member.spelling] = given
            }
        }

        self.typeMembers = typeMembers
        self.extended = documents.enumerated().flatMap { handed, held in
            Set(held.members.keys).union(held.typeMembers.keys).sorted().map { head in
                Placed(head, at: Place(held.document.home(of: head), in: held.document), of: handed)
            }
        }
    }

    // MARK: - Public
    // The type table of these declarations. A document's types take a run of
    // type rows the way its declarations take a run of table rows, in the
    // order the documents stand.
    func table(standing documents: [any Declaring], numbered linkage: Linkage) -> TypeTable {
        TypeTable(
            types: types.mapValues(\.held),
            contracts: contracts.mapValues(\.held),
            typeMembers: typeMembers.values.map(\.held),
            standing: Prelude.types.keys.sorted() + documents.flatMap { document in document.types.keys.sorted() },
            of: linkage
        )
    }

    // MARK: - Private
}
