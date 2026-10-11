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

// Data as a carrier spells it, read as the value it is.
@Suite("What a document spells data as")
struct ValueNotationTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "what a carrier spells reads as the value it spells",
        arguments: [
            ("null", Value.null),
            ("true", .bool(true)),
            ("42", .int(42)),
            ("3.5", .double(3.5)),
            ("\"warp\"", .string("warp")),
            ("[1, \"two\", null]", .array([.int(1), .string("two"), .null])),
            ("{\"id\": \"a\", \"done\": false}", .dictionary(["id": .string("a"), "done": .bool(false)])),
            ("{\"nested\": [{\"deep\": 1}]}", .dictionary(["nested": .array([.dictionary(["deep": .int(1)])])]))
        ]
    )
    func aSpellingReadsAsItsValue(_ written: String, _ sut: Value) throws {
        // When
        let read = try JSONDecoder().decode(ValueReader.self, from: Data(written.utf8))

        // Then
        #expect(read.value == sut)
    }

    @Test("a decoder walks bytes where it walks an array")
    func aDecoderWalksBytesWhereItWalksAnArray() throws {
        // Given. The two spellings are one collection to anything reading
        // elements out, and `Data` is still held to its own spelling, so an
        // array of small numbers cannot quietly become bytes.
        func decoding<T: Decodable>(_ type: T.Type, from value: Value) throws -> T {
            try T(from: ValueDecoder(value: value, codingPath: [], steps: [], userInfo: [:]))
        }

        // When / Then
        #expect(try decoding([Int].self, from: .bytes([1, 2])) == [1, 2])
        #expect(try decoding([Int].self, from: .array([.int(1), .int(2)])) == [1, 2])

        // And. Asking for `Data` is answered by the containers, which hold bytes
        // to their own spelling. An array of small numbers is refused there
        // rather than let through to `Data`'s own decoding, which reads an
        // unkeyed list and would quietly make bytes of it.
        struct Held: Decodable { let blob: Data }

        #expect(try decoding(Held.self, from: .dictionary(["blob": .bytes([1, 2])])).blob == Data([1, 2]))

        #expect(throws: ReadingError.self) {
            try decoding(Held.self, from: .dictionary(["blob": .array([.int(1), .int(2)])]))
        }
    }

    @Test("a foreign numeral past the Int reads as the Double the carrier holds")
    func aForeignNumeralPastTheIntReadsAsDouble() throws {
        // When / Then. A JSON number is a binary64 by the carrier's own nature:
        // its digits cannot be told from a fraction, and whatever exactness the
        // writing had was the carrier's to lose before this reader saw it; the
        // warp encodings are where every size is exact
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
        // Given. The bridge holds the Value itself, so a fraction that happens
        // to be whole must not be re-guessed from its spelling and come back an
        // int
        let whole = Value.double(5)
        let decoder = ValueDecoder(value: whole, codingPath: [], steps: [], userInfo: [:])

        // When
        let read = try ValueReader(from: decoder)

        // Then
        #expect(read.value == whole)
    }

    // MARK: - Public
    // MARK: - Private
}
