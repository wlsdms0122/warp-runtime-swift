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
// declared name is then a second spelling of. A notation that reads bare
// records reads a mapping under no form's key as the record.
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
            self.declared = try Self.record(from: try keyed.superDecoder(forKey: AnyCodingKey(stringValue: Self.recordKey.spelling)))
        } else if decoder.notation.readsBareRecords, !keys.contains(where: { key in TypeForm(key) != nil }) {
            self.declared = try Self.record(from: decoder)
        } else {
            self.declared = .alias(try TypeReader(from: decoder).type)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A record's fields, each a type. Each field is read where it stands, so a
    // refusal inside one keeps its own place and its own sentence.
    private static func record(from decoder: Decoder) throws -> TypeDeclaration {
        guard (try? decoder.container(keyedBy: AnyCodingKey.self)) != nil else {
            throw ReadingError("a record is a mapping of its fields to their types", at: decoder.steps)
        }

        return .record(try decoder.read([Name: TypeReader].self).mapValues(\.type))
    }
}
