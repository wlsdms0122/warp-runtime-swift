//
//  Decoder+Reading.swift
//  WarpSyntax
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp

extension Decoder {
    // Where this reading has reached, in the document's own terms. Nothing
    // where the reading is not this package's, which is the honest answer for a
    // decoder whose descent nobody here watched.
    var steps: [Place.Step] { (self as? ValueDecoder)?.steps ?? [] }

    // The notation this reading is in. A reading handed none reads a
    // document, which has no spellings.
    var notation: Notation { userInfo[.notation] as? Notation ?? .canonical }

    // Read what is written here, standing on it, so a reader judging a value
    // after reading it refuses at the place it read. The same door
    // `ValueDecoder.decode` is, reached from a decoder handed over as the
    // protocol; a decoder that is somebody else's reads as itself.
    func read<T: Decodable>(_ type: T.Type) throws -> T {
        guard let decoder = self as? ValueDecoder else { return try T(from: self) }

        return try decoder.decode(type)
    }

    // A record keyed by names. A value's keys are names already, and a key
    // from a decoder that is not this package's is read as one here.
    func read<T: Decodable>(_ type: [Name: T].Type) throws -> [Name: T] {
        guard let decoder = self as? ValueDecoder else {
            let container = try container(keyedBy: AnyCodingKey.self)

            return try container.allKeys
                .map(\.stringValue)
                .sorted()
                .reduce(into: [Name: T]()) { read, key in
                    read[try Name.read(key, at: steps)] = try container.decode(T.self, forKey: AnyCodingKey(stringValue: key))
                }
        }

        return try decoder.read(type)
    }

    func read<T: Decodable>(_ type: [T].Type) throws -> [T] {
        guard let decoder = self as? ValueDecoder else { return try [T](from: self) }

        return try decoder.read(type)
    }

    // The reading under a key, standing on it.
    func descending(to key: some CodingKey) throws -> Decoder {
        guard let decoder = self as? ValueDecoder else {
            return try container(keyedBy: AnyCodingKey.self)
                .superDecoder(forKey: AnyCodingKey(stringValue: key.stringValue))
        }

        return try decoder.descending(to: key.stringValue)
    }

    // The same, and nothing where the key is not written or holds null.
    func descendingIfPresent(to key: some CodingKey) throws -> Decoder? {
        guard let decoder = self as? ValueDecoder else {
            let container = try container(keyedBy: AnyCodingKey.self)
            let written = AnyCodingKey(stringValue: key.stringValue)

            guard container.contains(written), try !container.decodeNil(forKey: written) else { return nil }

            return try container.superDecoder(forKey: written)
        }

        return try decoder.descendingIfPresent(to: key.stringValue)
    }
}
