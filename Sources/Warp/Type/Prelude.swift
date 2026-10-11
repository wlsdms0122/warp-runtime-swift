//
//  Prelude.swift
//  Warp
//
//  Created by JSilver on 10/11/26.
//

import Foundation

// What the language declares itself, which every link holds ahead of its
// documents: the contract a map's key answers, which asks no procedures,
// its claims about the types the language names that answer it, and the two
// records the run builds, the failure a rescue binds and the round a loop
// binds. No document declares one of these names, and a mention of one is
// that declaration wherever it is written.
enum Prelude {
    // The records, each a name beside its fields.
    static let types: [Name: TypeExpression] = [
        TypeSpelling.failure: .record([
            FailurePayload.type: .string,
            FailurePayload.message: .string,
            FailurePayload.details: .dictionary(key: .string, value: .any)
        ]),
        TypeSpelling.round: .record([Prelude.index: .int])
    ]

    static let contracts: [Name: [Name: ContractProcedure]] = [TypeSpelling.hashable: [:]]

    // Every kind a value is but a procedure, which is the same as no value,
    // answers `Hashable`.
    static let claims: [Name: Set<Name>] = Dictionary(
        uniqueKeysWithValues: [
            TypeSpelling.null,
            TypeSpelling.bool,
            TypeSpelling.int,
            TypeSpelling.double,
            TypeSpelling.string,
            TypeSpelling.array,
            TypeSpelling.dictionary
        ].map { type in (type, [TypeSpelling.hashable]) }
    )

    // Every name declared here.
    static let names = Set(types.keys).union(contracts.keys)

    // The field a round holds: how many rounds ran before it.
    static let index: Name = "index"

    // Where the run puts the fields of the two records it builds, as their
    // declarations lay them out.
    static let failure = Layout(
        name: TypeSpelling.failure,
        ordered: [FailurePayload.details, FailurePayload.message, FailurePayload.type]
    )
    static let round = Layout(name: TypeSpelling.round, ordered: [Prelude.index])

    // Where the declarations stand: ahead of every document, written by none.
    static let document = Place.Document.assembled
}
