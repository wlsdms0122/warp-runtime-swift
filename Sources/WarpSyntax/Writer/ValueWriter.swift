//
//  ValueWriter.swift
//  WarpSyntax
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// Data written the way a document spells it — `ValueReader` the other way round,
// and the reason both live here: `Value` is the language's data type and knows
// nothing about being written down, so the mapping belongs in one place and this
// is it.
//
// The pair round-trips as far as the carrier can carry: a Codable carrier's
// number grammar is its own, so a whole-worth fraction may come back as the
// int of the same worth — worth survives the trip, and the kind survives
// where the carrier can say it. The warp encodings are where the kind is the
// text's own fact at every value. A procedure has no spelling, so writing one
// refuses rather than putting something in the text that reading it back
// could not answer with.
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

        // A Codable carrier has no compact spelling for bytes, and
        // `bytes = array<byte>` says what to write instead: the array they
        // are. It reads back as that array rather than as bytes, which is the
        // same thing this carrier does to `1.0` — a spelling is a fact about
        // the value, and a carrier that cannot hold one loses it. Refusing
        // here instead would close the only way out for a value that never
        // spelled itself bytes: an `array<int>` slot hands on what it was
        // given, and what it was given may have been written `x"6869"`.
        //
        // Both spellings go out through the one projection that owns the
        // equation, so neither can be written a way the other is not.
        case .bytes, .array:
            guard let elements = value.elements else {
                preconditionFailure("a value with a collection's spelling had no elements")
            }

            try container.encode(elements.map(ValueWriter.init))

        // A carrier keys its fields by Swift's equality, which folds
        // spellings a value keeps apart. What a value holds is a name, and one
        // name is one spelling, so the fold has nothing to fold.
        case .record, .dictionary:
            guard let held = value.asDictionary else { return }

            try container.encode(
                Swift.Dictionary(
                    uniqueKeysWithValues: held.entries.map { entry in
                        (entry.name.spelling, ValueWriter(entry.value))
                    }
                )
            )

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
}
