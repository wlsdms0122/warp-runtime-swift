//
//  ExtensionReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/13/26.
//

import Foundation
import Warp

// What a document gives a type, as it writes it under `extensions` keyed by
// the type: the contracts the type answers under `satisfies`, and its members
// under `procedures`, each a procedure under the name it has there. A struct's
// declaration writes the same two keys beside its fields.
public struct ExtensionReader: Decodable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case satisfies
        case procedures
    }

    // MARK: - Property
    let satisfies: Set<Name>
    let procedures: [Name: Procedure]

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "extension")

        (self.satisfies, self.procedures) = try Self.given(from: decoder)
    }

    // MARK: - Public
    // The two keys, read off a mapping that may write others beside them.
    // The contracts are a set of names: order and repeats are the one
    // spelling's to hold.
    static func given(from decoder: Decoder) throws -> (satisfies: Set<Name>, procedures: [Name: Procedure]) {
        let notation = decoder.notation
        let satisfies = try decoder.descendingIfPresent(to: CodingKeys.satisfies)
        let procedures = try decoder.descendingIfPresent(to: CodingKeys.procedures)

        return (
            Set(
                try (satisfies?.read([String].self) ?? []).enumerated().map { position, spelled in
                    notation.qualified(
                        try Name.read(spelled, at: (satisfies?.steps ?? []) + [.index(position)]),
                        as: .type
                    )
                }
            ),
            try procedures?.read([Name: ProcedureReader].self).mapValues(\.procedure) ?? [:]
        )
    }

    // MARK: - Private
}
