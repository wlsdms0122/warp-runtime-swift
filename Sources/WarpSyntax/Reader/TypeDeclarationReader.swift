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
// takes under `typeParameters`, each beside its bound, and what the
// document gives it the way an extension does, or any type, which the
// declared name is then a second spelling of.
struct TypeDeclarationReader: Decodable {
    // MARK: - Property
    let declared: TypeDeclaration

    // The contracts the struct adopts, its type members and its members,
    // which an alias has none of.
    let satisfies: Set<Name>
    let types: [Name: TypeExpression]
    let procedures: [Name: Procedure]

    // The key a struct is declared under.
    static let structKey: Name = "struct"

    // The key a struct lists its type parameters under, in the order a
    // mention hands their types.
    static let typeParametersKey: Name = "typeParameters"

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        guard let keyed = try? decoder.container(keyedBy: AnyCodingKey.self) else {
            self.declared = .alias(try TypeReader.Written(from: decoder).unbounded())
            self.satisfies = []
            self.types = [:]
            self.procedures = [:]

            return
        }

        let keys = Set(keyed.allKeys.map(\.name))

        guard keys.contains(Self.structKey) else {
            self.declared = .alias(try TypeReader.Written(from: decoder).unbounded())
            self.satisfies = []
            self.types = [:]
            self.procedures = [:]

            return
        }

        let given = ExtensionReader.CodingKeys.allCases.map(\.name)

        if let unknown = keys.subtracting([Self.structKey, Self.typeParametersKey] + given).min() {
            throw ReadingError(
                "a struct writes '\(unknown)', and is written with `\(Self.structKey)`,"
                    + " `\(Self.typeParametersKey)`, "
                    + given.map { key in "`\(key)`" }.joined(separator: ", ") + " alone",
                at: decoder.steps
            )
        }

        (self.satisfies, self.types, self.procedures) = try ExtensionReader.given(from: decoder)

        let fields = try Self.fields(from: keyed.superDecoder(forKey: AnyCodingKey(stringValue: Self.structKey.spelling)))
        let typeParameters = try Self.typeParameters(from: decoder.descendingIfPresent(to: AnyCodingKey(stringValue: Self.typeParametersKey.spelling)))

        self.declared = .struct(fields, typeParameters: typeParameters?.names ?? [], bounds: typeParameters?.bounds ?? [:])
    }

    // MARK: - Public
    // MARK: - Private
    // A struct's fields, each a type. Each field is read where it stands, so a
    // refusal inside one keeps its own place and its own sentence.
    private static func fields(from decoder: Decoder) throws -> [Name: TypeExpression] {
        guard case .dictionary = try ValueReader(from: decoder).value else {
            throw ReadingError("a struct is a mapping of its fields to their types", at: decoder.steps)
        }

        return try decoder.read([Name: TypeReader.Written].self).mapValues { field in try field.unbounded() }
    }

    // The names a struct takes types under, in order, each beside its bound.
    private static func typeParameters(from decoder: Decoder?) throws -> IntroducedNamesReader? {
        try decoder.map(IntroducedNamesReader.init(reading:))
    }
}
