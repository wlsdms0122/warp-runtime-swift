//
//  Prelude.swift
//  Warp
//
//  Created by JSilver on 10/11/26.
//

import Foundation

// What the language declares itself, which every link holds ahead of its
// documents: the contract a dictionary's key conforms to, which asks no procedures,
// its claims about the types the language names that conform to it, the two
// structs the run builds, the failure a catch binds and the round a loop
// binds, and the marker an Optional's some holds a none in. No document
// declares one of these names. A mention of one is that declaration wherever
// it is written, save the marker's, which only the language writes: it is how
// a value is held, and no type a program reads.
enum Prelude {
    // The structs, each a name beside its fields.
    static let types: [Name: TypeDeclaration] = [
        TypeSpelling.failure: .struct([
            FailurePayload.type: .string,
            FailurePayload.message: .string,
            FailurePayload.details: .dictionary(key: .string, value: .any)
        ]),
        TypeSpelling.round: .struct([Prelude.index: .int]),
        TypeSpelling.marker: .struct([Prelude.markerField: .any])
    ]

    static let contracts: [Name: Contract] = [TypeSpelling.hashable: Contract(procedures: [:])]

    // Every type the language names a value an instance of conforms to
    // `Hashable`, and so does every Optional of what conforms to it. A
    // procedure, which is the same as no value, is none of them.
    static let claims: [Head: Set<Name>] = Dictionary(
        uniqueKeysWithValues: TypeExpression.nominalTypes.keys.map { type in (Head(type), [TypeSpelling.hashable]) }
    ).merging([
        Head(
            TypeSpelling.optional,
            arguments: [.parameter(name: TypeSpelling.wrapped)],
            bounds: [TypeSpelling.wrapped: [TypeSpelling.hashable]]
        ): [TypeSpelling.hashable]
    ]) { language, _ in language }

    // Every name declared here.
    static let names = Set(types.keys).union(contracts.keys)

    // Every name declared here a document may write.
    static let mentioned = names.subtracting([TypeSpelling.marker])

    // The field a round holds: how many rounds ran before it.
    static let index: Name = "index"

    // The field the marker holds: the none it holds.
    static let markerField: Name = "wrapped"

    // Where the declarations stand: ahead of every document, written by none,
    // before the first a host hands over.
    static let document = Place.Document.assembled
    static let handed = -1
}
