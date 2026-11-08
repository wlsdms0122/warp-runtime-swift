//
//  ValueReaderTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// Data as a document spells it, read as the value it is.
@Suite("What a document spells data as")
struct ValueReaderTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "what a document spells reads as the value it spells",
        arguments: [
            Value.null,
            .bool(true),
            .int(42),
            .double(3.5),
            .string("warp"),
            .array([.int(1), .string("two"), .null]),
            .dictionary(["id": .string("a"), "done": .bool(false)]),
            .dictionary(["nested": .array([.dictionary(["deep": .int(1)])])])
        ]
    )
    func aSpellingReadsAsItsValue(_ sut: Value) throws {
        // Given
        let decoder = ValueDecoder(value: sut, codingPath: [], steps: [], userInfo: [:])

        // When
        let read = try ValueReader(from: decoder)

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

        // And. Asking for `Data` is handled by the containers, which hold bytes
        // to their own spelling. An array of small numbers is refused there
        // rather than let through to `Data`'s own decoding, which reads an
        // unkeyed list and would quietly make bytes of it.
        struct Held: Decodable { let blob: Data }

        #expect(try decoding(Held.self, from: .dictionary(["blob": .bytes([1, 2])])).blob == Data([1, 2]))

        #expect(throws: ReadingError.self) {
            try decoding(Held.self, from: .dictionary(["blob": .array([.int(1), .int(2)])]))
        }
    }

    @Test("a decoder that is not the value bridge is refused")
    func aForeignDecoderIsRefused() throws {
        // When / Then
        #expect(throws: ReadingError.self) {
            try JSONDecoder().decode(ValueReader.self, from: Data("42".utf8))
        }
    }

    @Test("a numeral keeps its kind across the Value bridge")
    func aBridgedNumberKeepsItsKind() throws {
        // Given. The bridge holds the Value itself, so a floating-point number
        // that happens to be whole must not be re-guessed from its spelling and
        // come back an int
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
