//
//  TypeDeclarationReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/11/26.
//

import Foundation
import Warp

// A type a module declares, as a document writes it under `types`: a struct,
// its fields under `struct`, each beside its type, or an enum, its cases
// under `enum`, each beside the fields it carries, the type parameters it
// takes under `typeParameters`, each beside its bound, and what the
// document gives it the way an extension does, or any type, which the
// declared name is then a second spelling of.
struct TypeDeclarationReader: Decodable {
    // MARK: - Property
    let declared: TypeDeclaration

    // The contracts the struct or the enum adopts, its type members and its
    // members,
    // which an alias has none of.
    let satisfies: Set<Name>
    let types: [Name: TypeExpression]
    let procedures: [Name: Procedure]

    // The key a struct is declared under.
    static let structKey: Name = "struct"

    // The key an enum is declared under.
    static let enumKey: Name = "enum"

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

        guard keys.contains(Self.structKey) || keys.contains(Self.enumKey) else {
            self.declared = .alias(try TypeReader.Written(from: decoder).unbounded())
            self.satisfies = []
            self.types = [:]
            self.procedures = [:]

            return
        }

        let isEnum = keys.contains(Self.enumKey)

        guard !isEnum || !keys.contains(Self.structKey) else {
            throw ReadingError(
                "writes `\(Self.enumKey)` beside `\(Self.structKey)`, which is two declarations under one name",
                at: try decoder.steps
            )
        }

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: ExtensionReader.CodingKeys.self,
            extra: [Self.structKey.spelling, Self.enumKey.spelling, Self.typeParametersKey.spelling],
            context: isEnum ? "enum" : "struct"
        )

        (self.satisfies, self.types, self.procedures) = try ExtensionReader.given(from: decoder)

        let typeParameters = try Self.typeParameters(from: decoder.descendingIfPresent(to: AnyCodingKey(stringValue: Self.typeParametersKey.spelling)))
        let names = typeParameters?.names ?? []
        let bounds = typeParameters?.bounds ?? [:]

        guard isEnum else {
            let fields = try Self.fields(from: keyed.superDecoder(forKey: AnyCodingKey(stringValue: Self.structKey.spelling)))

            self.declared = .struct(fields, typeParameters: names, bounds: bounds)

            return
        }

        let cases = try Self.cases(from: keyed.superDecoder(forKey: AnyCodingKey(stringValue: Self.enumKey.spelling)))

        self.declared = .enum(cases, typeParameters: names, bounds: bounds)
    }

    // MARK: - Public
    // MARK: - Private
    // A struct's fields, each a type. Each field is read where it stands, so a
    // refusal inside one keeps its own place and its own sentence.
    private static func fields(from decoder: Decoder) throws -> [Name: TypeExpression] {
        guard case .dictionary = try ValueReader(from: decoder).value else {
            throw ReadingError("a struct is a dictionary of its fields to their types", at: try decoder.steps)
        }

        return try decoder.read([Name: TypeReader.Written].self).mapValues { field in try field.unbounded() }
    }

    // An enum's cases, each the fields it carries. A field is read as written,
    // `var` included, which the load refuses on a case's field.
    private static func cases(from decoder: Decoder) throws -> [Name: [Name: TypeExpression]] {
        guard case .dictionary = try ValueReader(from: decoder).value else {
            throw ReadingError("an enum is a dictionary of its cases to the fields each carries", at: try decoder.steps)
        }

        return try decoder.read([Name: ValueReader].self).keys.reduce(into: [:]) { cases, label in
            let carried = try decoder.descending(to: AnyCodingKey(stringValue: label.spelling))

            guard case .dictionary = try ValueReader(from: carried).value else {
                throw ReadingError("a case is a dictionary of the fields it carries to their types", at: try carried.steps)
            }

            cases[label] = try carried.read([Name: TypeReader.Written].self).mapValues { field in try field.unbounded() }
        }
    }

    // The names a struct or an enum takes types under, in order, each beside its bound.
    private static func typeParameters(from decoder: Decoder?) throws -> IntroducedNamesReader? {
        try decoder.map(IntroducedNamesReader.init(reading:))
    }
}
