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

// The readable projection. The writer has one layout, sorted keys and two
// spaces an indent, and the reader takes any layout that spells the same value:
// what a document is comes off the canonical writing, not off the text it
// arrived in.
@Suite("The text encoding")
struct TextEncodingTests {
    // MARK: - Property
    // MARK: - Test
    @Test("every kind of value survives the round trip")
    func everyKindComesBack() throws {
        // Given
        let document = Value.object([
            "null": .null,
            "flags": .array([.bool(true), .bool(false)]),
            "counts": .array([.int(0), .int(-1), .int(Int.max), .int(Int.min)]),
            "ratio": .double(3.5),
            "name": .string("héllo, 世界"),
            "spaced key": .string("a\nb\t\"c\""),
            "empty": .object([:]),
            "nothing": .array([])
        ])

        // Then
        #expect(try TextEncoding.value(from: TextEncoding.text(from: document)) == document)
    }

    @Test("the text is the text the format says")
    func theGoldenText() throws {
        // Given — the same document the binary golden holds, laid out for eyes.
        // If this test moves, the format moved, and the format version had
        // better move with it.
        let document = Value.object([
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

        // Then
        #expect(try TextEncoding.text(from: document) == golden)
        #expect(try TextEncoding.value(from: golden) == document)
    }

    @Test("a whole number and a fraction are different tokens")
    func wholeAndFractionDiffer() throws {
        // Given — the difference is grammar, not a reader's guess
        #expect(try TextEncoding.value(from: "warpt 1\n1\n") == .int(1))
        #expect(try TextEncoding.value(from: "warpt 1\n1.0\n") == .double(1))
        #expect(try TextEncoding.value(from: "warpt 1\n-3\n") == .int(-3))
    }

    @Test("a number has one spelling, and the grammar holds it")
    func aSecondNumberSpellingIsRefused() {
        // Given: each of these parses to a number the writer spells another
        // way. Layout is free. What a number is written as is not.
        for text in [
            "warpt 1\n1.50\n",  // a longer fraction
            "warpt 1\n1e2\n"    // an exponent the writer does not use here
        ] {
            #expect {
                try TextEncoding.value(from: text)
            } throws: { error in
                "\(error)".contains("one writing")
            }
        }
    }

    @Test("layout is the writer's and not the reader's: any layout reads to the one value")
    func anyLayoutReadsToTheOneValue() throws {
        // Given: the writer's text, and the same document laid out inline,
        // over-indented, and without the final newline
        let document = Value.object(["a": .int(1), "b": .string("A")])
        let canonical = try TextEncoding.text(from: document)

        for text in [
            "warpt 1\n{ a 1 b \"A\" }\n",
            "warpt 1\n{\n      a 1\n  b \"A\"\n    }\n",
            "warpt 1\n{\n  a 1\n  b \"A\"\n}"
        ] {
            #expect(try TextEncoding.value(from: text) == document, "\(text)")
        }

        // And writing any of them back is the one text
        #expect(try TextEncoding.text(from: try TextEncoding.value(from: "warpt 1\n{ a 1 b \"A\" }\n")) == canonical)
    }

    @Test("keys read in any order, and a key written twice is refused")
    func aShuffledKeyReads() throws {
        #expect(
            try TextEncoding.value(from: "warpt 1\n{\n  b 1\n  a 2\n}\n")
                == .object(["a": .int(2), "b": .int(1)])
        )

        #expect {
            try TextEncoding.value(from: "warpt 1\n{\n  a 1\n  a 2\n}\n")
        } throws: { error in
            "\(error)".contains("twice")
        }
    }

    @Test("a field name outside normal form C is refused")
    func aDenormalKeyIsRefused() {
        // Given — é as e-plus-mark: valid UTF-8, ascending order, and a second
        // byte spelling for a name the value model reads as é
        let text = "warpt 1\n{\n  \"\u{65}\u{301}\" 1\n}\n"

        #expect {
            try TextEncoding.value(from: text)
        } throws: { error in
            "\(error)".contains("normal form")
        }
    }

    @Test("a key that is not a word is written in quotes, and read back")
    func aQuotedKeyComesBack() throws {
        // Given
        let document = Value.object(["spaced key": .int(1), "가나다": .int(2)])

        // When
        let text = try TextEncoding.text(from: document)

        // Then — and a name outside ASCII is quoted too, because what counts
        // as "a letter" beyond ASCII depends on whose Unicode tables a host
        // shipped, and the canonical layout cannot
        #expect(text.contains("\"spaced key\""))
        #expect(text.contains("\"가나다\""))
        #expect(try TextEncoding.value(from: text) == document)
    }

    @Test("text that does not begin as a document is refused")
    func aForeignHeaderIsRefused() {
        for text in ["{}", "", "json 1\n{}", "warpt\n{}"] {
            #expect(throws: (any Error).self) {
                try TextEncoding.value(from: text)
            }
        }
    }

    @Test("a document laid out by a later format is refused, not guessed at")
    func aLaterFormatIsRefused() {
        #expect {
            try TextEncoding.value(from: "warpt 2\nnull")
        } throws: { error in
            "\(error)".contains("later") || "\(error)".contains("format 2")
        }

        #expect(throws: (any Error).self) {
            try TextEncoding.value(from: "warpt 0\nnull")
        }
    }

    @Test("text after the document is refused")
    func trailingTextIsRefused() {
        #expect {
            try TextEncoding.value(from: "warpt 1\nnull null")
        } throws: { error in
            "\(error)".contains("the text did not")
        }
    }

    @Test("text that ends inside a value is refused")
    func truncationIsRefused() {
        // Given — every healthy prefix of an unhealthy ending
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
            #expect(throws: (any Error).self) {
                try TextEncoding.value(from: text)
            }
        }
    }

    @Test("a close with nothing to close is refused")
    func aStrayCloseIsRefused() {
        for text in ["warpt 1\n]", "warpt 1\n}", "warpt 1\n[ } ]", "warpt 1\n{ a ] }"] {
            #expect(throws: (any Error).self) {
                try TextEncoding.value(from: text)
            }
        }
    }

    @Test("a bare word the format never assigned is refused")
    func anUnknownWordIsRefused() {
        for text in ["warpt 1\nyes", "warpt 1\nnul", "warpt 1\n--1", "warpt 1\n1.5.5", "warpt 1\n1e"] {
            #expect(throws: (any Error).self) {
                try TextEncoding.value(from: text)
            }
        }
    }

    @Test("a record writes a field name where one is due")
    func aValueWhereAKeyIsDueIsRefused() throws {
        for text in ["warpt 1\n{ 1 2 }", "warpt 1\n{ [ ] null }", "warpt 1\n{ {} null }"] {
            #expect {
                try TextEncoding.value(from: text)
            } throws: { error in
                "\(error)".contains("field name")
            }
        }

        // And `null` in key position is a field called null, because position
        // is what tells a key from a value here
        #expect(
            try TextEncoding.value(from: "warpt 1\n{\n  null 1\n}\n")
                == .object(["null": .int(1)])
        )
    }

    @Test("an escape that names no character is refused")
    func aBrokenEscapeIsRefused() throws {
        for text in [
            #"warpt 1\#n"\q""#,
            #"warpt 1\#n"\u12""#,
            #"warpt 1\#n"\ud800""#,
            #"warpt 1\#n"\ud800A""#
        ] {
            #expect(throws: (any Error).self) {
                try TextEncoding.value(from: text)
            }
        }

        // And a whole pair is refused too: the character it spells is written
        // as itself
        #expect(throws: (any Error).self) {
            try TextEncoding.value(from: "warpt 1\n\"\\ud83d\\ude00\"\n")
        }
    }

    @Test("an escape for a character that has a shorter spelling is refused")
    func aLongEscapeIsRefused() throws {
        // Given: a letter written raw, a newline with its own escape, and
        // uppercase hex for a control character
        for text in [
            "warpt 1\n\"\\u0041\"\n",
            "warpt 1\n\"\\u000a\"\n",
            "warpt 1\n\"\\u001B\"\n"
        ] {
            #expect(throws: (any Error).self, "\(text)") {
                try TextEncoding.value(from: text)
            }
        }

        // And the one escape the writer does use reads
        #expect(try TextEncoding.value(from: "warpt 1\n\"\\u001b\"\n") == .string("\u{1b}"))
    }

    @Test("a control character is carried as an escape, never raw")
    func controlCharactersTravelEscaped() throws {
        // Given
        let text = try TextEncoding.text(from: .string("a\u{01}b"))

        // Then
        #expect(text.contains("\\u0001"))
        #expect(try TextEncoding.value(from: text) == .string("a\u{01}b"))

        // And raw in, refused
        #expect(throws: (any Error).self) {
            try TextEncoding.value(from: "warpt 1\n\"a\u{01}b\"")
        }
    }

    @Test("a document nested past following is refused")
    func bottomlessNestingIsRefused() {
        // Given — six hundred brackets, two keystrokes held down
        let text = "warpt 1\n"
            + String(repeating: "[", count: 600)
            + "null"
            + String(repeating: "]", count: 600)

        #expect {
            try TextEncoding.value(from: text)
        } throws: { error in
            "\(error)".contains("deeper")
        }
    }

    @Test("what a document cannot carry is refused on the way out")
    func theUnwritableIsRefusedWhenWriting() {
        for value in [Value.double(.infinity), .double(.nan)] {
            #expect(throws: (any Error).self) {
                try TextEncoding.data(from: value)
            }
        }

        #expect(throws: (any Error).self) {
            try TextEncoding.data(
                from: .procedure(try Closure.assembled())
            )
        }
    }

    @Test("bytes are lowercase hex, two digits each, and nothing else")
    func bytesSpellingIsHeld() throws {
        // Given — the one spelling, both ways
        #expect(try TextEncoding.value(from: "warpt 1\nx\"\"\n") == .bytes([]))
        #expect(try TextEncoding.text(from: .bytes([0x00, 0xff])) == "warpt 1\nx\"00ff\"\n")

        // And the spellings that are not it — refused by the grammar, with
        // the grammar's own words, not left to the canonical backstop
        for text in [
            "warpt 1\nx\"6A\"\n",    // uppercase
            "warpt 1\nx\"6a 73\"\n"  // spaced
        ] {
            #expect {
                try TextEncoding.value(from: text)
            } throws: { error in
                "\(error)".contains("lowercase hex")
            }
        }

        #expect {
            try TextEncoding.value(from: "warpt 1\nx\"6a7\"\n")
        } throws: { error in
            "\(error)".contains("two digits")
        }

        #expect {
            try TextEncoding.value(from: "warpt 1\nx\"6a")
        } throws: { error in
            "\(error)".contains("ends inside")
        }
    }

    @Test("a field name outside normal form C is refused on the way out too")
    func aDenormalKeyIsRefusedWhenWriting() {
        #expect {
            try TextEncoding.text(from: .object(["e\u{301}": .int(1)]))
        } throws: { error in
            "\(error)".contains("normal form")
        }
    }

    @Test("bytes that are not UTF-8 are refused before they are text")
    func foreignBytesAreRefused() {
        #expect {
            try TextEncoding.value(from: Data([0x80, 0xff]))
        } throws: { error in
            "\(error)".contains("UTF-8")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
