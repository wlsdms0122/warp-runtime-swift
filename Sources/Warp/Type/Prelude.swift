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
// structs the run builds, the failure a rescue binds and the round a loop
// binds. No document declares one of these names, and a mention of one is
// that declaration wherever it is written.
enum Prelude {
    // The structs, each a name beside its fields.
    static let types: [Name: TypeDeclaration] = [
        TypeSpelling.failure: .struct([
            FailurePayload.type: .string,
            FailurePayload.message: .string,
            FailurePayload.details: .dictionary(key: .string, value: .any)
        ]),
        TypeSpelling.round: .struct([Prelude.index: .int])
    ]

    static let contracts: [Name: [Name: ContractProcedure]] = [TypeSpelling.hashable: [:]]

    // Every type the language names a value an instance of answers
    // `Hashable`. A procedure, which is the same as no value, is none of
    // them.
    static let claims: [Name: Set<Name>] = Dictionary(
        uniqueKeysWithValues: TypeExpression.nominalTypes.keys.map { type in (type, [TypeSpelling.hashable]) }
    )

    // Every name declared here.
    static let names = Set(types.keys).union(contracts.keys)

    // The field a round holds: how many rounds ran before it.
    static let index: Name = "index"

    // Where the declarations stand: ahead of every document, written by none,
    // before the first a host hands over.
    static let document = Place.Document.assembled
    static let handed = -1
}
