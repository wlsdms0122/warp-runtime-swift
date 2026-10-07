//
//  ValueWriter.swift
//  WarpSyntax
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// Data written the way a document spells it. `ValueReader` the other way round.
//
// The pair round-trips as far as the carrier can carry: a Codable carrier's
// number grammar is its own, so a whole-worth fraction may come back as the int
// of the same worth. Worth survives the trip, and the kind survives where the
// carrier can say it. The warp encodings are where the kind is the text's own
// fact at every value. A procedure has no spelling, so writing one refuses
// rather than putting something in the text that reading it back could not
// answer with.
public struct ValueWriter: Encodable {
    // MARK: - Property
    public let value: Value

    // MARK: - Initializer
    public init(_ value: Value) {
        self.value = value
    }

    // MARK: - Public
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case .null:
            try container.encodeNil()

        case let .bool(bool):
            try container.encode(bool)

        case let .int(int):
            try container.encode(int)

        case let .double(double):
            try container.encode(double)

        case let .string(string):
            try container.encode(string)

        // A Codable carrier has no compact spelling for bytes, and `bytes =
        // array<byte>` says what to write instead: the array they are. It reads
        // back as that array rather than as bytes, which is the same thing this
        // carrier does to `1.0`. A spelling is a fact about the value, and a
        // carrier that cannot hold one loses it. Refusing here instead would
        // close the only way out for a value that never spelled itself bytes:
        // an `Array<Int>` slot hands on what it was given, and what it was
        // given may have been written `x"6869"`.
        case let .bytes(bytes):
            try container.encode(bytes.map { byte in ValueWriter(.int(Int(byte))) })

        case let .array(elements):
            try container.encode(elements.map(ValueWriter.init))

        // A carrier keys its fields by Swift's equality, which folds
        // spellings a value keeps apart. What a value holds is a name, and one
        // name is one spelling, so the fold has nothing to fold.
        case let .record(record):
            try container.encode(carried(record.asDictionary))

        case let .dictionary(held):
            try container.encode(carried(held))

        // A body is code, and a document spells code as a procedure rather than
        // as data. Writing a marker would make a document that cannot be read
        // back into what it came from.
        case .procedure:
            throw EncodingError.invalidValue(
                value,
                .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "a procedure is code, and data is what a document spells"
                )
            )
        }
    }

    // MARK: - Private
    private func carried(_ held: Value.Dictionary) -> [String: ValueWriter] {
        Dictionary(
            uniqueKeysWithValues: held.entries.map { entry in
                (entry.name.spelling, ValueWriter(entry.value))
            }
        )
    }
}
