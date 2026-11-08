//
//  Contract.swift
//  Warp
//
//  Created by JSilver on 10/13/26.
//

import Foundation

// What a value's type must have to stand under a contract: the procedures it
// implements, each by its member of that name and held to the signature asked,
// and the types it gives, each by its type member of that name. A type the contract asks is held to the
// contracts `bounds` names for it, so a signature reading it through a type
// parameter, `some T.Item`, may ask of it what they ask.
public struct Contract: Sendable, Equatable, ExpressibleByDictionaryLiteral {
    // MARK: - Property
    public let procedures: [Name: Signature]
    public let types: Set<Name>

    // The contracts each type it asks is held to, by its name. A type bounded
    // by none stands nowhere here.
    public let bounds: [Name: Set<Name>]

    // Every declared name this reaches: the contracts its bounds name and
    // what its procedures do.
    var mentions: Set<Name> {
        procedures.values.reduce(into: Set(bounds.values.joined())) { mentioned, procedure in
            mentioned.formUnion(procedure.mentions)
        }
    }

    // MARK: - Initializer
    public init(
        procedures: [Name: Signature] = [:],
        types: Set<Name> = [],
        bounds: [Name: Set<Name>] = [:]
    ) {
        self.procedures = procedures
        self.types = types
        self.bounds = bounds.filter { _, contracts in !contracts.isEmpty }
    }

    // A contract asking procedures alone, written as them.
    public init(dictionaryLiteral procedures: (Name, Signature)...) {
        self.init(procedures: Dictionary(uniqueKeysWithValues: procedures))
    }

    // MARK: - Public
    // MARK: - Private
}
