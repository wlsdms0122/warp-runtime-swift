//
//  TypeDeclarationReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/11/26.
//

import Foundation
import Warp

// A type a module declares, as a document writes it under `types`: a struct,
// its fields under `struct`, each beside its type, the type parameters it
// takes under `typeParameters` and their bounds under `bounds`, or any type,
// which the declared name is then a second spelling of.
struct TypeDeclarationReader: Decodable {
    // MARK: - Property
    let declared: TypeDeclaration

    // The key a struct is declared under.
    static let structKey: Name = "struct"

    // The key a struct lists its type parameters under, in the order a
    // mention hands their types.
    static let typeParametersKey: Name = "typeParameters"

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        guard let keyed = try? decoder.container(keyedBy: AnyCodingKey.self) else {
            self.declared = .alias(try TypeReader(from: decoder).type)

            return
        }

        let keys = Set(keyed.allKeys.map(\.name))

        guard keys.contains(Self.structKey) else {
            self.declared = .alias(try TypeReader(from: decoder).type)

            return
        }

        let boundsKey = SignatureFieldsReader.CodingKeys.bounds.name

        if let unknown = keys.subtracting([Self.structKey, Self.typeParametersKey, boundsKey]).min() {
            throw ReadingError(
                "a struct writes '\(unknown)', and is written with `\(Self.structKey)`,"
                    + " `\(Self.typeParametersKey)` and `\(boundsKey)` alone",
                at: decoder.steps
            )
        }

        let fields = try Self.fields(from: keyed.superDecoder(forKey: AnyCodingKey(stringValue: Self.structKey.spelling)))
        let typeParameters = try Self.typeParameters(from: decoder.descendingIfPresent(to: AnyCodingKey(stringValue: Self.typeParametersKey.spelling)))
        let bounds = try decoder.descendingIfPresent(to: SignatureFieldsReader.CodingKeys.bounds)

        self.declared = .struct(
            fields,
            typeParameters: typeParameters,
            bounds: try BoundsReader().bounds(
                try bounds?.read([Name: String].self),
                in: decoder.notation,
                at: bounds?.steps ?? decoder.steps
            )
        )
    }

    // MARK: - Public
    // MARK: - Private
    // A struct's fields, each a type. Each field is read where it stands, so a
    // refusal inside one keeps its own place and its own sentence.
    private static func fields(from decoder: Decoder) throws -> [Name: TypeExpression] {
        guard case .dictionary = try ValueReader(from: decoder).value else {
            throw ReadingError("a struct is a mapping of its fields to their types", at: decoder.steps)
        }

        return try decoder.read([Name: TypeReader].self).mapValues(\.type)
    }

    // The names a struct takes types under, in order. A struct taking none
    // writes no list, so the one way to say it is to leave the key out.
    private static func typeParameters(from decoder: Decoder?) throws -> [Name] {
        guard let decoder else { return [] }

        let written = try decoder.read([String].self)

        guard !written.isEmpty else {
            throw ReadingError(
                "lists no type parameters, and a struct taking none leaves `\(Self.typeParametersKey)` out",
                at: decoder.steps
            )
        }

        return try written.enumerated().map { position, spelling in
            try Name.read(spelling, at: decoder.steps + [.index(position)])
        }
    }
}
