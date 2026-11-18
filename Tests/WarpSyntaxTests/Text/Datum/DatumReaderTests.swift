//
//  DatumReaderTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax

// The first layer: atoms and lists, a token's kind said by its first
// characters, and a value's one spelling.
@Suite("The datum reader")
struct DatumReaderTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a token's first characters say its kind")
    func aTokenSaysItsKind() throws {
        // When
        let read = try Self.read(#"null true false 1 -3 1.5 "a" x"6a" a.b - `x y` (f)"#)

        // Then
        #expect(read == [
            "null", "true", "false", "int 1", "int -3", "double 1.5", "string a", "bytes 6a",
            "name a.b", "name -", "name x y", "(name f)"
        ])
    }

    @Test("a name in backticks is the name bare, and the backticks leave no trace")
    func backticksLeaveNoTrace() throws {
        // When / Then
        #expect(try Self.read("`x` x `null` `a\\`b` `\"`") == ["name x", "name x", "name null", "name a`b", "name \""])
    }

    @Test("a number has one spelling, and a token begun as one that is not refuses")
    func aNumberHasOneSpelling() {
        // Given
        for text in ["1.50", "01", "+1", "1.", "1e2", "1a", "-0"] {
            // When / Then
            #expect(throws: TextRefused.self, "\(text)") { try DatumReader().data(of: Array(text.unicodeScalars)) }
        }
    }

    @Test("an escape is the writer's or it refuses")
    func anEscapeIsTheWriters() throws {
        // When / Then
        #expect(try Self.read(#""a\"b\\c\n\u0001""#) == ["string a\"b\\c\n\u{1}"])

        for text in [#""\u0041""#, #""\u000a""#, #""\`""#, #""\q""#, "\"a\u{1}\""] {
            #expect(throws: TextRefused.self, "\(text)") { try DatumReader().data(of: Array(text.unicodeScalars)) }
        }
    }

    @Test("what the grammar leaves no reading for refuses")
    func whatHasNoReadingRefuses() {
        // Given
        for text in ["a\"b\"", "\"a\"b", "(a", "a)", "``", "x\"6A\"", "x\"6\"", "a\u{1}b"] {
            // When / Then
            #expect(throws: TextRefused.self, "\(text)") { try DatumReader().data(of: Array(text.unicodeScalars)) }
        }
    }

    @Test(
        "a refusal stands where what it refuses begins, or at the end of a text that ends too soon",
        arguments: [
            ("(a 1.50)", 3),
            ("a x\"6\"", 2),
            ("\"a\u{1}\"", 2),
            ("x\"6A\"", 3),
            (#""a\q""#, 2),
            (#""\u0041""#, 1),
            (#""\u00zz""#, 1),
            ("``", 0),
            ("a\"b\"", 1),
            ("x (a", 2),
            ("a)", 1),
            ("\"ab", 3),
            (#""\"#, 2),
            (#""\u00"#, 5),
            ("x\"6", 3)
        ]
    )
    func aRefusalStandsWhereItBegins(text: String, offset: Int) {
        // When
        let refusal = #expect(throws: TextRefused.self) { try DatumReader().data(of: Array(text.unicodeScalars)) }

        // Then
        #expect(refusal?.offset == offset, "\(text)")
    }

    // MARK: - Public
    // MARK: - Private
    private static func read(_ text: String) throws -> [String] {
        try DatumReader().data(of: Array(text.unicodeScalars)).map(shown)
    }

    private static func shown(_ datum: Datum) -> String {
        switch datum.form {
        case .null: "null"
        case let .bool(bool): "\(bool)"
        case let .int(int): "int \(int)"
        case let .double(double): "double \(double)"
        case let .string(string): "string \(string)"
        case let .bytes(bytes): "bytes \(bytes.spelling)"
        case let .name(name): "name \(name)"
        case let .list(elements): "(\(elements.map(shown).joined(separator: " ")))"
        }
    }
}
