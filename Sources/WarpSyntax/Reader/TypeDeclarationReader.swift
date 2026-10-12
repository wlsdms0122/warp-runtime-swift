//
//  TypeDeclarationReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/11/26.
//

import Foundation
import Warp

// A type a module declares, as a document writes it under `types`: a struct,
// its fields under `struct`, each beside its type, or any type, which the
// declared name is then a second spelling of.
struct TypeDeclarationReader: Decodable {
    // MARK: - Property
    let declared: TypeDeclaration

    // The key a struct is declared under.
    static let structKey: Name = "struct"

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        guard let keyed = try? decoder.container(keyedBy: AnyCodingKey.self) else {
            self.declared = .alias(try TypeReader(from: decoder).type)

            return
        }

        let keys = keyed.allKeys.map(\.name)

        if keys == [Self.structKey] {
            let fields = try keyed.superDecoder(forKey: AnyCodingKey(stringValue: Self.structKey.spelling))

            self.declared = try Self.structDeclaration(from: fields)
        } else {
            self.declared = .alias(try TypeReader(from: decoder).type)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A struct's fields, each a type. Each field is read where it stands, so a
    // refusal inside one keeps its own place and its own sentence.
    private static func structDeclaration(from decoder: Decoder) throws -> TypeDeclaration {
        guard case .dictionary = try ValueReader(from: decoder).value else {
            throw ReadingError("a struct is a mapping of its fields to their types", at: decoder.steps)
        }

        return .struct(try decoder.read([Name: TypeReader].self).mapValues(\.type))
    }
}
