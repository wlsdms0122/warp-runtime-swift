//
//  ValueNotationTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// Reading and writing data are one mapping seen from two sides, and the whole of
// what they promise is that they are the same one.
@Suite("What a document spells data as")
struct ValueNotationTests {
    // MARK: - Lifecycle
    // MARK: - Test
    @Test(
        "what is written reads back as what it was",
        arguments: [
            Value.null,
            .bool(true),
            .int(42),
            .double(3.5),
            .string("warp"),
            .array([.int(1), .string("two"), .null]),
            .record(["id": .string("a"), "done": .bool(false)]),
            .record(["nested": .array([.record(["deep": .int(1)])])])
        ]
    )
    func writingRoundTrips(_ sut: Value) throws {
        // When
        let written = try JSONEncoder().encode(ValueWriter(sut))
        let read = try JSONDecoder().decode(ValueReader.self, from: written)

        // Then
        #expect(read.value == sut)
    }

    @Test("bytes are written as the array they are, and come back as that array")
    func bytesAreWrittenAsTheArrayTheyAre() throws {
        // Given — a Codable carrier has no compact spelling for bytes, and
        // `bytes = array<byte>` says what to write instead. It reads back as
        // the array rather than as bytes, which is what this carrier does to
        // `1.0` too — a spelling it cannot hold is a spelling it loses.
        let written = try JSONEncoder().encode(ValueWriter(.bytes([104, 105])))

        #expect(String(decoding: written, as: UTF8.self) == "[104,105]")
        #expect(
            try JSONDecoder().decode(ValueReader.self, from: written).value
                == .array([.int(104), .int(105)])
        )

        // Refusing instead would close the only way out for a value that never
        // spelled itself bytes: an `array<int>` slot hands on what it was
        // given, and what it was given may have been written `x"6869"`.
        #expect(
            try TypeExpression.array(.int).settling(.bytes([104, 105]), at: "value")
                == .bytes([104, 105])
        )
    }

    @Test("a decoder walks bytes where it walks an array")
    func aDecoderWalksBytesWhereItWalksAnArray() throws {
        // The two spellings are one collection to anything reading elements
        // out — and `Data` is still held to its own spelling, so an array of
        // small numbers cannot quietly become bytes.
        func decoding<T: Decodable>(_ type: T.Type, from value: Value) throws -> T {
            try T(from: ValueDecoder(value: value, codingPath: [], steps: [], userInfo: [:]))
        }

        #expect(try decoding([Int].self, from: .bytes([1, 2])) == [1, 2])
        #expect(try decoding([Int].self, from: .array([.int(1), .int(2)])) == [1, 2])

        // Asking for `Data` is answered by the containers, which hold bytes to
        // their own spelling — an array of small numbers is refused there
        // rather than let through to `Data`'s own decoding, which reads an
        // unkeyed list and would quietly make bytes of it.
        struct Held: Decodable { let blob: Data }

        #expect(try decoding(Held.self, from: .record(["blob": .bytes([1, 2])])).blob == Data([1, 2]))

        #expect(throws: (any Error).self) {
            try decoding(Held.self, from: .record(["blob": .array([.int(1), .int(2)])]))
        }
    }

    @Test("a foreign numeral past the word reads as the double the carrier holds")
    func aForeignNumeralPastTheWordReadsAsDouble() throws {
        // Given — a JSON number is a binary64 by the carrier's own nature:
        // its digits cannot be told from a fraction, and whatever exactness
        // the writing had was the carrier's to lose before this reader saw
        // it; the warp encodings are where every size is exact
        #expect(
            try JSONDecoder().decode(ValueReader.self, from: Data("9223372036854775808".utf8)).value
                == .double(9223372036854775808.0)
        )
        #expect(
            try JSONDecoder().decode(ValueReader.self, from: Data("1e19".utf8)).value
                == .double(1e19)
        )
        #expect(
            try JSONDecoder().decode(ValueReader.self, from: Data("1.5".utf8)).value
                == .double(1.5)
        )
        #expect(
            try JSONDecoder().decode(ValueReader.self, from: Data("42".utf8)).value
                == .int(42)
        )
    }

    @Test("a numeral keeps its kind across the Value bridge")
    func aBridgedNumberKeepsItsKind() throws {
        // Given — the bridge holds the Value itself, so a fraction that
        // happens to be whole must not be re-guessed from its spelling and
        // come back an int
        let whole = Value.double(5)
        let decoder = ValueDecoder(value: whole, codingPath: [], steps: [], userInfo: [:])

        // When
        let read = try ValueReader(from: decoder)

        // Then
        #expect(read.value == whole)
    }

    @Test("a procedure has no spelling, so writing one refuses")
    func writingAProcedureRefuses() throws {
        // Given
        let sut = Value.procedure(
            Closure.assembled()
        )

        // When / Then
        #expect(throws: EncodingError.self) {
            try JSONEncoder().encode(ValueWriter(sut))
        }
    }
}
