//
//  ExtensionReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/13/26.
//

import Foundation
import Warp

// What a document gives a type, as it writes it under `extensions` keyed by
// the type: the contracts the type adopts under `satisfies`, its type
// members under `types`, each a type under the name it has there, and its
// members under `procedures`, each a procedure under the name it has there.
// A struct's declaration writes the same three keys beside its fields.
struct ExtensionReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case satisfies
        case types
        case procedures
    }

    // MARK: - Property
    let satisfies: Set<Name>
    let types: [Name: TypeExpression]
    let procedures: [Name: Procedure]

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "extension")

        (self.satisfies, self.types, self.procedures) = try Self.given(from: decoder)
    }

    // MARK: - Public
    // The head an extension's key spells. Refused at `steps`, where the key
    // is written.
    static func head(of key: Name, at steps: [Place.Step]) throws -> Head {
        do {
            return try TypeReader(at: steps).head(key.spelling)
        } catch let refusal as TypeFormError {
            throw ReadingError(refusal.message, at: steps)
        }
    }

    // The three keys, read off a mapping that may write others beside them.
    // The contracts are a set of names: order and repeats are the one
    // spelling's to hold.
    static func given(
        from decoder: Decoder
    ) throws -> (satisfies: Set<Name>, types: [Name: TypeExpression], procedures: [Name: Procedure]) {
        let satisfies = try decoder.descendingIfPresent(to: CodingKeys.satisfies)
        let types = try decoder.descendingIfPresent(to: CodingKeys.types)
        let procedures = try decoder.descendingIfPresent(to: CodingKeys.procedures)

        return (
            Set(
                try (satisfies?.read([String].self) ?? []).enumerated().map { position, spelled in
                    try Name.read(spelled, at: (satisfies?.steps ?? []) + [.index(position)])
                }
            ),
            try types?.read([Name: TypeReader.Written].self).mapValues { member in try member.unbounded() } ?? [:],
            try procedures?.read([Name: ProcedureReader].self).mapValues(\.procedure) ?? [:]
        )
    }

    // MARK: - Private
}
