//
//  TypeNodeTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax

// A type as a node and the text the tree holds, both ways, its parts in the
// order written, and one node for one text.
@Suite("A type node")
struct TypeNodeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a node writes the type grammar's spelling, and the spelling reads back as the node", arguments: [
        ("Int", "Int"),
        ("Self.Item", "Self.Item"),
        ("(array Int)", "Array<Int>"),
        ("(dictionary String (array Int))", "Dictionary<String, Array<Int>>"),
        ("(named App.Box Int String)", "App.Box<Int, String>"),
        ("(nullable Int)", "Int?"),
        ("(nullable (procedure (const)))", "(const Procedure)?"),
        ("(nullable (procedure (parameters) (returns Int)))", "(() -> Int)?"),
        ("(composition B A)", "B & A"),
        ("(composition A A)", "A & A"),
        ("(some T)", "some T"),
        ("(some T App.Named Hashable)", "some T: App.Named & Hashable"),
        ("(some T.Item)", "some T.Item"),
        ("(some T.Item Hashable)", "some T.Item: Hashable"),
        ("(some Self.Item)", "some Self.Item"),
        ("(inout (nullable Int))", "inout Int?"),
        ("(var Int)", "var Int"),
        ("Procedure", "Procedure"),
        ("(procedure (const))", "const Procedure"),
        ("(procedure (isolated) (const))", "isolated const Procedure"),
        ("(procedure (const) (const))", "const const Procedure"),
        ("(named Dictionary Int)", "Dictionary<Int>"),
        ("(procedure (const) (isolated) (parameters Int (inout B)) (failing b a) (returns (nullable R)))",
         "const isolated (Int, inout B) throws(b, a) -> R?"),
        ("(procedure (parameters) (failing (anything)) (returns Int))", "() throws -> Int"),
        ("(procedure (parameters) (failing) (returns Int))", "() throws() -> Int"),
        ("(procedure (parameters (procedure (parameters Int) (returns Int))) (returns (procedure (parameters) (returns Int))))",
         "((Int) -> Int) -> () -> Int")
    ])
    func aNodeAndItsText(written: String, text: String) throws {
        // Given
        let node = try Self.datum(written)

        // When
        let spelled = try TypeNode().text(of: node)
        let read = try TypeNode().datum(of: text)

        // Then
        #expect(spelled == text)
        #expect(try TypeNode().text(of: read) == text)
        #expect(try DatumWriter().line(of: read) == written)
    }

    @Test("a node another node's text is written as is refused", arguments: [
        "(named Array Int)",
        "(named App.Box)",
        "(composition A)",
        "(nullable (inout Int))",
        "(procedure)",
        "(procedure (parameters Int))",
        "(procedure (const) (failing a))",
        "`A & B`",
        "(array `Int>`)",
        "(failing (anything))",
        "(composition some A)",
        "(composition inout A)",
        "(procedure (returns R) (parameters A))",
        "(array \u{301})",
        "\"Int\""
    ])
    func aSecondNodeIsRefused(written: String) throws {
        // Given
        let node = try Self.datum(written)

        // When / Then
        #expect(throws: Unplaced.self) { try TypeNode().text(of: node) }
    }

    @Test("a spelling no node writes back is refused on the way out", arguments: [
        "Array<Int,Int>",
        "Array< Int>",
        "Int -> Int",
        "(Int)",
        "(Int)?"
    ])
    func aSpellingNoNodeWrites(text: String) {
        // When / Then
        #expect(throws: Unplaced.self) { try TypeNode().datum(of: text) }
    }

    @Test("a type node nests as deep as the bound, counted from the type written inside the outermost")
    func aNodeNestsToTheBound() throws {
        // Given
        let bound = Value.nestingBound
        let node = { (levels: Int) in String(repeating: "(array ", count: levels) + "Int" + String(repeating: ")", count: levels) }
        let text = { (levels: Int) in String(repeating: "Array<", count: levels) + "Int" + String(repeating: ">", count: levels) }

        // When / Then
        #expect(try TypeNode().text(of: Self.datum(node(bound))) == text(bound))
        #expect(try DatumWriter().line(of: TypeNode().datum(of: text(bound))) == node(bound))
        #expect(throws: Unplaced.self) { try TypeNode().text(of: Self.datum(node(bound + 1))) }
        #expect(throws: Unplaced.self) { try TypeNode().datum(of: text(bound + 1)) }
    }

    // MARK: - Public
    // MARK: - Private
    private static func datum(_ text: String) throws -> Datum {
        try #require(try DatumReader().data(of: Array(text.unicodeScalars)).first)
    }
}
