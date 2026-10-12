//
//  TypeDeclarationReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/11/26.
//

import Foundation
import Warp

// A type a module declares, as a document writes it under `types`: a record,
// its fields under `record`, each beside its type, or any type, which the
// declared name is then a second spelling of.
struct TypeDeclarationReader: Decodable {
    // MARK: - Property
    let declared: TypeDeclaration

    // The key a record is declared under.
    static let recordKey: Name = "record"

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        guard let keyed = try? decoder.container(keyedBy: AnyCodingKey.self) else {
            self.declared = .alias(try TypeReader(from: decoder).type)

            return
        }

        let keys = keyed.allKeys.map(\.name)

        if keys == [Self.recordKey] {
            let fields = try keyed.superDecoder(forKey: AnyCodingKey(stringValue: Self.recordKey.spelling))

            self.declared = try Self.record(from: fields)
        } else {
            self.declared = .alias(try TypeReader(from: decoder).type)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A record's fields, each a type. Each field is read where it stands, so a
    // refusal inside one keeps its own place and its own sentence.
    private static func record(from decoder: Decoder) throws -> TypeDeclaration {
        guard case .dictionary = try ValueReader(from: decoder).value else {
            throw ReadingError("a record is a mapping of its fields to their types", at: decoder.steps)
        }

        return .record(try decoder.read([Name: TypeReader].self).mapValues(\.type))
    }
}
