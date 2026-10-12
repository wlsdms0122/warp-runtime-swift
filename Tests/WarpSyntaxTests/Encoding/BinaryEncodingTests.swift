//
//  BinaryEncodingTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax
import WarpTestSupport

// Warp's own bytes, held to the two promises that justify having our own:
// the same document is the same bytes, and bytes the writer would not write
// are refused rather than read charitably.
@Suite("The binary encoding")
struct BinaryEncodingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every kind of value survives the round trip")
    func everyKindComesBack() throws {
        // Given. One of everything a document can hold, nested enough to make
        // the walk mean something
        let document = Value.dictionary([
            "null": .null,
            "flags": .array([.bool(true), .bool(false)]),
            "counts": .array([.int(0), .int(-1), .int(Int.max), .int(Int.min)]),
            "ratio": .double(3.5),
            "name": .string("héllo, 世界"),
            "empty": .dictionary([:]),
            "nothing": .array([])
        ])

        // When
        let bytes = try BinaryEncoding().data(from: document)

        // Then
        #expect(try BinaryEncoding().value(from: bytes) == document)
    }

    @Test("the same document is the same bytes, whatever order it was built in")
    func equalDocumentsAreEqualBytes() throws {
        // Given. Two tables that hold the same fields, written into the
        // dictionary in opposite orders
        var forward: [Name: Value] = [:]
        var backward: [Name: Value] = [:]

        let keys: [Name] = ["a", "b", "c", "d", "e"]

        for (index, key) in keys.enumerated() {
            forward[key] = .int(index)
        }

        for (index, key) in keys.enumerated().reversed() {
            backward[key] = .int(index)
        }

        // When / Then
        #expect(
            try BinaryEncoding().data(from: .dictionary(forward))
                == BinaryEncoding().data(from: .dictionary(backward))
        )
    }

    @Test("the bytes are the bytes the format says")
    func theGoldenBytes() throws {
        // Given. A document small enough to lay out by hand. If this test
        // moves, the format moved, and the format version had better move with
        // it. A round-trip test alone would happily follow the code anywhere.
        let document = Value.dictionary([
            "a": .int(1),
            "b": .array([.bool(true), .null]),
            "c": .string("hi"),
            "d": .double(1.5),
            "e": .bytes([0x6a, 0x73])
        ])

        let golden: [UInt8] = [
            0x57, 0x41, 0x52, 0x50,   // WARP
            0x01,                     // format 1
            0x07, 0x05,               // a map of five
            0x05, 0x01, 0x61, 0x03, 0x02,               // "a": int 1 (zigzag 2)
            0x05, 0x01, 0x62, 0x06, 0x02, 0x02, 0x00,   // "b": [true, null]
            0x05, 0x01, 0x63, 0x05, 0x02, 0x68, 0x69,   // "c": "hi"
            0x05, 0x01, 0x64, 0x04,                     // "d": the fraction 1.5
            0x3f, 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x05, 0x01, 0x65, 0x08, 0x02, 0x6a, 0x73    // "e": two bytes
        ]

        // When / Then
        #expect(try BinaryEncoding().data(from: document) == Data(golden))
        #expect(try BinaryEncoding().value(from: Data(golden)) == document)
    }

    @Test("a whole number and a fraction are different bytes")
    func wholeAndFractionDiffer() throws {
        // Given / When. The failure JSON invites: `1` and `1.0` as the same
        // token
        let whole = try BinaryEncoding().data(from: .int(1))
        let fraction = try BinaryEncoding().data(from: .double(1))

        // Then
        #expect(whole != fraction)
        #expect(try BinaryEncoding().value(from: whole) == .int(1))
        #expect(try BinaryEncoding().value(from: fraction) == .double(1))
    }

    @Test("bytes that do not begin as a document are refused")
    func aForeignHeaderIsRefused() throws {
        // Given. JSON bytes, which is what will actually be handed to this
        // reader by mistake
        for bytes in [Data("{}".utf8), Data(), Data([0x57, 0x41])] {
            // When / Then
            #expect {
                try BinaryEncoding().value(from: bytes)
            } throws: { error in
                "\(error)".contains("begin") || "\(error)".contains("end")
            }
        }
    }

    @Test("a document laid out by a later format is refused, not guessed at")
    func aLaterFormatIsRefused() {
        // Given. The header's version exists for exactly this reader
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x02, 0x00])

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("later") || "\(error)".contains("format 2")
        }

        // And a format that never existed is not an earlier one
        #expect(throws: EncodingRefused.self) {
            try BinaryEncoding().value(from: Data([0x57, 0x41, 0x52, 0x50, 0x00, 0x00]))
        }
    }

    @Test("bytes after the document are refused")
    func trailingBytesAreRefused() {
        // Given. A null, and then a byte nobody asked for. Reading what fits
        // and ignoring the rest is how two readers run two different programs.
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x00, 0x00])

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("the bytes did not")
        }
    }

    @Test("a tag the format never assigned is refused")
    func anUnknownTagIsRefused() {
        // Given
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x0a])

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("begins with")
        }
    }

    @Test("a length that claims more than the document holds is refused")
    func aLyingLengthIsRefused() {
        // Given. Text claiming four gigabytes, in a document of six bytes. The
        // refusal has to come before anything is set aside for the claim.
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x05, 0xff, 0xff, 0xff, 0xff, 0x0f])

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("claims more")
        }
    }

    @Test("nested claims cannot sum past the document")
    func nestedClaimsShareOneBudget() {
        // Given. Fifty maps, each opened with five bytes and each claiming a
        // hundred entries. Each claim alone fits the bytes that remain, which
        // is how a check local to one claim approved all fifty and set aside
        // memory for five thousand entries of a two-hundred-byte document.
        var bytes: [UInt8] = [0x57, 0x41, 0x52, 0x50, 0x01]

        for _ in 0..<50 {
            bytes += [0x07, 0x64, 0x05, 0x01, 0x61]   // a map of "a hundred", key "a"
        }

        bytes.append(0x00)

        // When / Then
        #expect {
            try BinaryEncoding().value(from: Data(bytes))
        } throws: { error in
            "\(error)".contains("claims more")
        }
    }

    @Test(
        "a map with its keys out of order is refused",
        arguments: [
            [0x05, 0x01, 0x62, 0x00, 0x05, 0x01, 0x61, 0x00],   // "b" before "a"
            [0x05, 0x01, 0x61, 0x00, 0x03, 0x02, 0x00],         // text before a number
            [0x03, 0x04, 0x00, 0x03, 0x02, 0x00]                // 2 before 1
        ] as [[UInt8]]
    )
    func aShuffledMapIsRefused(entries: [UInt8]) {
        // Given. Bytes the writer would never produce, so reading them would
        // mean two spellings of one document
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x07, 0x02] + entries)

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("order")
        }
    }

    @Test(
        "a map that holds a key twice is refused",
        arguments: [
            [0x05, 0x01, 0x61, 0x03, 0x02, 0x05, 0x01, 0x61, 0x03, 0x04],   // "a" and "a"
            [0x03, 0x02, 0x00, 0x04, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0, 0x00],   // 1 and 1.0
            [0x08, 0x01, 0x01, 0x00, 0x06, 0x01, 0x03, 0x02, 0x00]          // x"01" and [1]
        ] as [[UInt8]]
    )
    func aDuplicateKeyIsRefused(entries: [UInt8]) {
        // Given. One key twice, by the value model's sameness. Last-one-wins
        // is an answer, but it is the reader deciding what the writer meant.
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x07, 0x02] + entries)

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("order")
        }
    }

    @Test("a map's keys are values, written ascending by kind and then within it")
    func aMapIsKeyedByValues() throws {
        // Given. A key of every kind a map's keys are ordered by
        let map = Value.dictionary(
            try Value.Dictionary([
                (key: .array([.int(1)]), value: .int(5)),
                (key: .string(""), value: .int(4)),
                (key: .int(3), value: .int(3)),
                (key: .bool(true), value: .int(2)),
                (key: .null, value: .int(1))
            ])
        )

        let body: [UInt8] = [
            0x07, 0x05,
            0x00, 0x03, 0x02,               // null: 1
            0x02, 0x03, 0x04,               // true: 2
            0x03, 0x06, 0x03, 0x06,         // 3: 3
            0x05, 0x00, 0x03, 0x08,         // "": 4
            0x06, 0x01, 0x03, 0x02, 0x03, 0x0a   // [1]: 5
        ]

        // When / Then
        #expect(try BinaryEncoding().data(from: map) == Data([0x57, 0x41, 0x52, 0x50, 0x01] + body))
        #expect(try BinaryEncoding().value(from: Data([0x57, 0x41, 0x52, 0x50, 0x01] + body)) == map)
    }

    @Test("a record with its fields out of order is refused")
    func aShuffledRecordIsRefused() {
        // Given. "b" before "a" in a record of `A.P`
        let bytes = Data([
            0x57, 0x41, 0x52, 0x50, 0x01,
            0x09, 0x03, 0x41, 0x2e, 0x50, 0x02,
            0x01, 0x62, 0x00,   // b: null
            0x01, 0x61, 0x00    // a: null
        ])

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("order")
        }
    }

    @Test("a field name outside normal form C is refused")
    func aDenormalKeyIsRefused() throws {
        // Given. É as e-plus-mark: valid UTF-8, ascending order, and a second
        // byte spelling for a name whose NFC form is one character. Accepting
        // it would let one name sort to two places and a record hold a field
        // twice, losing one without a word.
        let bytes = Data([
            0x57, 0x41, 0x52, 0x50, 0x01,
            0x09, 0x03, 0x41, 0x2e, 0x50, 0x01,
            0x03, 0x65, 0xcc, 0x81, 0x00    // é (NFD): null
        ])

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("normal form")
        }

        // And the same name in NFC is a document
        let normal = Data([
            0x57, 0x41, 0x52, 0x50, 0x01,
            0x09, 0x03, 0x41, 0x2e, 0x50, 0x01,
            0x02, 0xc3, 0xa9, 0x00          // é (NFC): null
        ])

        #expect(try BinaryEncoding().value(from: normal) == Value.holding([(name: "é", value: .null)], named: "A.P"))
    }

    @Test("a map's text key is data, kept as its bytes spell it")
    func aTextKeyIsNeverNormalised() throws {
        // Given. É as e-plus-mark under a map, where a key is a value and a
        // string value travels byte-for-byte as written
        let bytes = Data([
            0x57, 0x41, 0x52, 0x50, 0x01,
            0x07, 0x01,
            0x05, 0x03, 0x65, 0xcc, 0x81, 0x00    // "é" (NFD): null
        ])

        // When
        let read = try BinaryEncoding().value(from: bytes)

        // Then
        #expect(try BinaryEncoding().data(from: read) == bytes)
    }

    @Test("bytes that end inside bytes are refused")
    func truncatedBytesAreRefused() {
        // Given. Bytes claiming three and carrying one
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x08, 0x03, 0x6a])

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("end inside")
        }
    }

    @Test("a field name outside normal form C never reaches the way out")
    func aDenormalKeyIsRefusedWhenWriting() {
        // Given. A record's field names are names, so there is no value
        // carrying one for a writing to refuse: the refusal is at the
        // initializer a name comes through.
        let decomposed = "e\u{301}"

        // When / Then
        #expect(throws: NameRefused.self) {
            try Name(decomposed)
        }
    }

    @Test("a number written longer than it is is refused")
    func aPaddedNumberIsRefused() {
        // Given. Zero written in two bytes. One value, one spelling; the second
        // spelling is where byte equality and document equality part.
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x03, 0x80, 0x00])

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("longer than it is")
        }
    }

    @Test("a number that does not fit in 64 bits is refused")
    func anOverflowingNumberIsRefused() {
        // Given. Eleven continuation bytes of all-ones
        let bytes = Data(
            [0x57, 0x41, 0x52, 0x50, 0x01, 0x03] + Array(repeating: UInt8(0xff), count: 11)
        )

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("64 bits")
        }
    }

    @Test("bytes that end in the middle of a value are refused")
    func truncationIsRefused() throws {
        // Given. A healthy document cut at every possible place. Whatever byte
        // it loses, the answer is a refusal and never a smaller document.
        let bytes = try BinaryEncoding().data(
            from: .dictionary(["a": .array([.int(300), .string("hi"), .double(1.5)])])
        )

        // When / Then
        for end in 5..<bytes.count {
            #expect(throws: EncodingRefused.self) {
                try BinaryEncoding().value(from: bytes.prefix(end))
            }
        }
    }

    @Test("a document nested past following is an attack, not a program")
    func bottomlessNestingIsRefused() {
        // Given. Six hundred arrays each holding the next. No writer recursing
        // over a real value produces this; a generator stamping two bytes does.
        let bytes = Data(
            [0x57, 0x41, 0x52, 0x50, 0x01]
                + Array(repeating: [0x06, 0x01], count: 600).flatMap { pair in pair }
                + [0x00]
        )

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("deeper")
        }
    }

    @Test("text that is not UTF-8 is refused")
    func foreignTextIsRefused() {
        // Given. A lone continuation byte where text was claimed
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x05, 0x01, 0x80])

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            (error as? EncodingRefused)?.message == "the text is not UTF-8"
        }
    }

    @Test(
        "a byte order mark is text like any other, in a String and in a key",
        arguments: [
            (Value.string("\u{FEFF}A"), [0x05, 0x04, 0xEF, 0xBB, 0xBF, 0x41]),
            (Value.dictionary(["\u{FEFF}": .int(1)]), [0x07, 0x01, 0x05, 0x03, 0xEF, 0xBB, 0xBF, 0x03, 0x02]),
            (
                Value.dictionary(["b": .int(1), "\u{FEFF}a": .int(2)]),
                [0x07, 0x02, 0x05, 0x01, 0x62, 0x03, 0x02, 0x05, 0x04, 0xEF, 0xBB, 0xBF, 0x61, 0x03, 0x04]
            )
        ] as [(Value, [UInt8])]
    )
    func aByteOrderMarkIsKept(value: Value, body: [UInt8]) throws {
        // Given
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01] + body)

        // When / Then. Written as its bytes, and read back as the value it was
        #expect(try BinaryEncoding().data(from: value) == bytes)
        #expect(try BinaryEncoding().value(from: bytes) == value)
    }

    @Test("what a document cannot carry is refused on the way out")
    func theUnwritableIsRefusedWhenWriting() async throws {
        // Given. The value model's edges, not this encoding's: these bytes
        // could be written, and the refusal is that no encoding may
        for value in [Value.double(.infinity), .double(.nan)] {
            // When / Then
            #expect(throws: EncodingRefused.self) {
                try BinaryEncoding().data(from: value)
            }
        }

        // And code is not data in any encoding
        let procedure = try await procedureValue()

        #expect(throws: EncodingRefused.self) {
            try BinaryEncoding().data(from: procedure)
        }
    }

    @Test("a fraction that cannot arrive is refused on the way in")
    func theUncarriableIsRefusedWhenReading() {
        // Given. Infinity's bit pattern, stamped by hand
        let bytes = Data([
            0x57, 0x41, 0x52, 0x50, 0x01,
            0x04, 0x7f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ])

        // When / Then
        #expect {
            try BinaryEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("no way to carry")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
