//
//  TextEncodingTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax
import WarpTestSupport

// The readable projection. The writer has one layout, sorted keys and two
// spaces an indent, and the reader takes any layout that spells the same value:
// what a document is comes off the canonical writing, not off the text it
// arrived in.
@Suite("The text encoding")
struct TextEncodingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every kind of value survives the round trip")
    func everyKindComesBack() throws {
        // Given
        let document = Value.dictionary([
            "null": .null,
            "flags": .array([.bool(true), .bool(false)]),
            "counts": .array([.int(0), .int(-1), .int(Int.max), .int(Int.min)]),
            "ratio": .double(3.5),
            "name": .string("héllo, 世界"),
            "spaced key": .string("a\nb\t\"c\""),
            "empty": .dictionary([:]),
            "nothing": .array([])
        ])

        // When / Then
        #expect(try TextEncoding().value(from: TextEncoding().text(from: document)) == document)
    }

    @Test("the text is the text the format says")
    func theGoldenText() throws {
        // Given. The same document the binary golden holds, laid out for eyes.
        // If this test moves, the format moved, and the format version had
        // better move with it.
        let document = Value.dictionary([
            "a": .int(1),
            "b": .array([.bool(true), .null]),
            "c": .string("hi"),
            "d": .double(1.5),
            "e": .bytes([0x6a, 0x73])
        ])

        let golden = """
        warpt 1
        {
          a 1
          b [
            true
            null
          ]
          c "hi"
          d 1.5
          e x"6a73"
        }

        """

        // When / Then
        #expect(try TextEncoding().text(from: document) == golden)
        #expect(try TextEncoding().value(from: golden) == document)
    }

    @Test("a whole number and a fraction are different tokens")
    func wholeAndFractionDiffer() throws {
        // When / Then. The difference is grammar, not a reader's guess
        #expect(try TextEncoding().value(from: "warpt 1\n1\n") == .int(1))
        #expect(try TextEncoding().value(from: "warpt 1\n1.0\n") == .double(1))
        #expect(try TextEncoding().value(from: "warpt 1\n-3\n") == .int(-3))
    }

    @Test("a number has one spelling, and the grammar holds it")
    func aSecondNumberSpellingIsRefused() {
        // Given. Each of these parses to a number the writer spells another
        // way. Layout is free. What a number is written as is not.
        for text in [
            "warpt 1\n1.50\n",  // a longer fraction
            "warpt 1\n1e2\n"    // an exponent the writer does not use here
        ] {
            // When / Then
            #expect {
                try TextEncoding().value(from: text)
            } throws: { error in
                "\(error)".contains("one writing")
            }
        }
    }

    @Test("layout is the writer's and not the reader's: any layout reads to the one value")
    func anyLayoutReadsToTheOneValue() throws {
        // Given. The writer's text, and the same document laid out inline,
        // over-indented, and without the final newline
        let document = Value.dictionary(["a": .int(1), "b": .string("A")])
        let canonical = try TextEncoding().text(from: document)

        for text in [
            "warpt 1\n{ a 1 b \"A\" }\n",
            "warpt 1\n{\n      a 1\n  b \"A\"\n    }\n",
            "warpt 1\n{\n  a 1\n  b \"A\"\n}"
        ] {
            // When / Then
            #expect(try TextEncoding().value(from: text) == document, "\(text)")
        }

        // And writing any of them back is the one text
        #expect(try TextEncoding().text(from: try TextEncoding().value(from: "warpt 1\n{ a 1 b \"A\" }\n")) == canonical)
    }

    @Test("keys read in any order, and a key written twice is refused")
    func aShuffledKeyReads() throws {
        // When / Then
        #expect(
            try TextEncoding().value(from: "warpt 1\n{\n  b 1\n  a 2\n}\n")
                == .dictionary(["a": .int(2), "b": .int(1)])
        )

        #expect {
            try TextEncoding().value(from: "warpt 1\n{\n  a 1\n  a 2\n}\n")
        } throws: { error in
            "\(error)".contains("twice")
        }
    }

    @Test("a field name outside normal form C is refused")
    func aDenormalKeyIsRefused() throws {
        // Given. É as e-plus-mark: valid UTF-8, ascending order, and a second
        // byte spelling for a name the value model reads as é
        let text = "warpt 1\nA.P {\n  \"\u{65}\u{301}\" 1\n}\n"

        // When / Then
        #expect {
            try TextEncoding().value(from: text)
        } throws: { error in
            "\(error)".contains("normal form")
        }

        // And under a map, where a key is a value, the same text is data and
        // written back as it was
        let map = "warpt 1\n{\n  \"\u{65}\u{301}\" 1\n}\n"

        #expect(try TextEncoding().text(from: try TextEncoding().value(from: map)).unicodeScalars.elementsEqual(map.unicodeScalars))
    }

    @Test("a key that is not an identifier is written in quotes, and read back")
    func aQuotedKeyComesBack() throws {
        // Given
        let document = Value.dictionary(["spaced key": .int(1), "가나다": .int(2)])

        // When
        let text = try TextEncoding().text(from: document)

        // Then, and a name outside ASCII is quoted too, because what counts as
        // "a letter" beyond ASCII depends on whose Unicode tables a host
        // shipped, and the canonical layout cannot
        #expect(text.contains("\"spaced key\""))
        #expect(text.contains("\"가나다\""))
        #expect(try TextEncoding().value(from: text) == document)
    }

    @Test("text that does not begin as a document is refused")
    func aForeignHeaderIsRefused() {
        // When / Then
        for text in ["{}", "", "json 1\n{}", "warpt\n{}"] {
            #expect(throws: EncodingRefused.self) {
                try TextEncoding().value(from: text)
            }
        }
    }

    @Test("a document laid out by a later format is refused, not guessed at")
    func aLaterFormatIsRefused() {
        // When / Then
        #expect {
            try TextEncoding().value(from: "warpt 2\nnull")
        } throws: { error in
            "\(error)".contains("later") || "\(error)".contains("format 2")
        }

        #expect(throws: EncodingRefused.self) {
            try TextEncoding().value(from: "warpt 0\nnull")
        }
    }

    @Test("text after the document is refused")
    func trailingTextIsRefused() {
        // When / Then
        #expect {
            try TextEncoding().value(from: "warpt 1\nnull null")
        } throws: { error in
            "\(error)".contains("the text did not")
        }
    }

    @Test("text that ends inside a value is refused")
    func truncationIsRefused() {
        // Given. Every healthy prefix of an unhealthy ending
        for text in [
            "warpt 1\n[",
            "warpt 1\n{",
            "warpt 1\n{ a",
            "warpt 1\n{ a 1",
            "warpt 1\n[ 1 2",
            "warpt 1\n\"unclosed",
            "warpt 1\n\"half an escape \\",
            "warpt 1\n"
        ] {
            // When / Then
            #expect(throws: EncodingRefused.self) {
                try TextEncoding().value(from: text)
            }
        }
    }

    @Test("a close with nothing to close is refused")
    func aStrayCloseIsRefused() {
        // When / Then
        for text in ["warpt 1\n]", "warpt 1\n}", "warpt 1\n[ } ]", "warpt 1\n{ a ] }"] {
            #expect(throws: EncodingRefused.self) {
                try TextEncoding().value(from: text)
            }
        }
    }

    @Test("a bare token the format never assigned is refused")
    func anUnknownTokenIsRefused() {
        // When / Then
        for text in ["warpt 1\nyes", "warpt 1\nnul", "warpt 1\n--1", "warpt 1\n1.5.5", "warpt 1\n1e"] {
            #expect(throws: EncodingRefused.self) {
                try TextEncoding().value(from: text)
            }
        }
    }

    @Test("a record writes a field name where one is due")
    func aValueWhereAKeyIsDueIsRefused() throws {
        // When / Then
        for text in ["warpt 1\nA.P { 1 2 }", "warpt 1\nA.P { [ ] null }", "warpt 1\nA.P { {} null }", "warpt 1\nA.P { null 1 }"] {
            #expect {
                try TextEncoding().value(from: text)
            } throws: { error in
                "\(error)".contains("field name")
            }
        }
    }

    @Test("a map's key is a value, and text written bare is text")
    func aMapIsKeyedByValues() throws {
        // Given. A key of each kind, and the text `null`, which bare would be
        // the value null
        let map = Value.dictionary(
            try Value.Dictionary([
                (key: .null, value: .int(1)),
                (key: .bool(false), value: .int(2)),
                (key: .int(-3), value: .int(3)),
                (key: .string("null"), value: .int(4)),
                (key: .string("a"), value: .int(5)),
                (key: .array([.int(1), .int(2)]), value: .int(6)),
                (key: .dictionary([:]), value: .int(7))
            ])
        )
        let text = "warpt 1\n{\n  null 1\n  false 2\n  -3 3\n  a 5\n  \"null\" 4\n  [\n    1\n    2\n  ] 6\n  {} 7\n}\n"

        // When / Then. Written in the key order, a key's value on the line
        // the key ends on, and read back as the map it was
        #expect(try TextEncoding().text(from: map) == text)
        #expect(try TextEncoding().value(from: text) == map)
    }

    @Test("a map holding one key twice is refused, by sameness")
    func aKeyWrittenTwiceBySamenessIsRefused() {
        // When / Then
        for text in ["warpt 1\n{ 1 null 1.0 null }", "warpt 1\n{ x\"01\" null [ 1 ] null }", "warpt 1\n{ a 1 \"a\" 2 }"] {
            #expect {
                try TextEncoding().value(from: text)
            } throws: { error in
                "\(error)".contains("twice")
            }
        }
    }

    @Test("a record named by one identifier has no writing as a map's key")
    func aRecordNamedByAnIdentifierIsNoKey() throws {
        // Given. Where a key stands `P { … }` reads as the text P and a map
        let map = Value.dictionary(try Value.Dictionary([(key: try Value.holding([], named: "P"), value: .int(1))]))

        // When / Then
        #expect {
            try TextEncoding().text(from: map)
        } throws: { error in
            "\(error)".contains("stands as a key")
        }

        // And one whose name is joined by a dot is written as it is
        let dotted = Value.dictionary(try Value.Dictionary([(key: try Value.holding([], named: "A.P"), value: .int(1))]))

        #expect(try TextEncoding().value(from: try TextEncoding().text(from: dotted)) == dotted)
    }

    @Test("an escape that names no character is refused")
    func aBrokenEscapeIsRefused() throws {
        // When / Then
        for text in [
            #"warpt 1\#n"\q""#,
            #"warpt 1\#n"\u12""#,
            #"warpt 1\#n"\ud800""#,
            #"warpt 1\#n"\ud800A""#
        ] {
            #expect(throws: EncodingRefused.self) {
                try TextEncoding().value(from: text)
            }
        }

        // And a whole pair is refused too: the character it spells is written
        // as itself
        #expect(throws: EncodingRefused.self) {
            try TextEncoding().value(from: "warpt 1\n\"\\ud83d\\ude00\"\n")
        }
    }

    @Test("an escape for a character that has a shorter spelling is refused")
    func aLongEscapeIsRefused() throws {
        // Given. A letter written raw, a newline with its own escape, and
        // uppercase hex for a control character
        for text in [
            "warpt 1\n\"\\u0041\"\n",
            "warpt 1\n\"\\u000a\"\n",
            "warpt 1\n\"\\u001B\"\n"
        ] {
            // When / Then
            #expect(throws: EncodingRefused.self, "\(text)") {
                try TextEncoding().value(from: text)
            }
        }

        // And the one escape the writer does use reads
        #expect(try TextEncoding().value(from: "warpt 1\n\"\\u001b\"\n") == .string("\u{1b}"))
    }

    @Test("a control character is carried as an escape, never raw")
    func controlCharactersTravelEscaped() throws {
        // Given / When
        let text = try TextEncoding().text(from: .string("a\u{01}b"))

        // Then
        #expect(text.contains("\\u0001"))
        #expect(try TextEncoding().value(from: text) == .string("a\u{01}b"))

        // And raw in, refused
        #expect(throws: EncodingRefused.self) {
            try TextEncoding().value(from: "warpt 1\n\"a\u{01}b\"")
        }
    }

    @Test("a document nested past following is refused")
    func bottomlessNestingIsRefused() {
        // Given. Six hundred brackets, two keystrokes held down
        let text = "warpt 1\n"
            + String(repeating: "[", count: 600)
            + "null"
            + String(repeating: "]", count: 600)

        // When / Then
        #expect {
            try TextEncoding().value(from: text)
        } throws: { error in
            "\(error)".contains("deeper")
        }
    }

    @Test("what a document cannot carry is refused on the way out")
    func theUnwritableIsRefusedWhenWriting() async throws {
        // Given
        let procedure = try await procedureValue()

        // When / Then
        for value in [Value.double(.infinity), .double(.nan)] {
            #expect(throws: EncodingRefused.self) {
                try TextEncoding().data(from: value)
            }
        }

        #expect(throws: EncodingRefused.self) {
            try TextEncoding().data(from: procedure)
        }
    }

    @Test("bytes are lowercase hex, two digits each, and nothing else")
    func bytesSpellingIsHeld() throws {
        // When / Then. The one spelling, both ways
        #expect(try TextEncoding().value(from: "warpt 1\nx\"\"\n") == .bytes([]))
        #expect(try TextEncoding().text(from: .bytes([0x00, 0xff])) == "warpt 1\nx\"00ff\"\n")

        // And the spellings that are not it. Refused by the grammar, with the
        // grammar's own terms, not left to the canonical backstop
        for text in [
            "warpt 1\nx\"6A\"\n",    // uppercase
            "warpt 1\nx\"6a 73\"\n"  // spaced
        ] {
            #expect {
                try TextEncoding().value(from: text)
            } throws: { error in
                "\(error)".contains("lowercase hex")
            }
        }

        #expect {
            try TextEncoding().value(from: "warpt 1\nx\"6a7\"\n")
        } throws: { error in
            "\(error)".contains("two digits")
        }

        #expect {
            try TextEncoding().value(from: "warpt 1\nx\"6a")
        } throws: { error in
            "\(error)".contains("ends inside")
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

    @Test("bytes that are not UTF-8 are refused before they are text")
    func foreignBytesAreRefused() {
        // When / Then
        #expect {
            try TextEncoding().value(from: Data([0x80, 0xff]))
        } throws: { error in
            "\(error)".contains("UTF-8")
        }
    }

    @Test("a text led by a byte order mark does not begin as a document")
    func aLeadingByteOrderMarkIsRefused() {
        // Given
        let bytes = Data([0xEF, 0xBB, 0xBF] + Array("warpt 1\n1\n".utf8))

        // When / Then
        #expect {
            try TextEncoding().value(from: bytes)
        } throws: { error in
            "\(error)".contains("does not begin as a warp document begins")
        }
    }

    @Test("a refusal says the line and column the reader stood at")
    func aRefusalIsPlaced() {
        // When / Then. A value where a field name is due: the reader stands on
        // the `2`.
        #expect {
            try TextEncoding().value(from: "warpt 1\nA.P {\n  a 1\n  2\n}\n")
        } throws: { error in
            Self.refused(error, "a record writes a field name here", at: 4, 3)
        }

        // And. Text that ends inside a record: the reader stands past the last
        // line.
        #expect {
            try TextEncoding().value(from: "warpt 1\n{\n  a\n")
        } throws: { error in
            Self.refused(error, "the text ends where a value should begin", at: 4, 1)
        }

        // And. A token the tokenizer refuses, before any value is read.
        #expect {
            try TextEncoding().value(from: "warpt 1\n[\n  \"a\"b\n]\n")
        } throws: { error in
            (error as? EncodingRefused)?.position == EncodingRefused.Position(line: 3, column: 6)
        }
    }

    // MARK: - Public
    // MARK: - Private
    private static func refused(_ error: any Error, _ message: String, at line: Int, _ column: Int) -> Bool {
        guard let refused = error as? EncodingRefused else { return false }

        return refused.message == message && refused.position == EncodingRefused.Position(line: line, column: column)
    }
}
