//
//  PathNodeTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax

// A path as a node and its rendering, both ways, a name alone being the path
// of that one name.
@Suite("A path node")
struct PathNodeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a node writes the path's rendering, and the rendering reads back as the node", arguments: [
        ("x", "x"),
        ("(path a (field b) (field? c))", "a.b?.c"),
        (#"(path a (index 0) (index? "k\"\\"))"#, #"a[0]?["k\"\\"]"#),
        ("(path a (index i) (index (path w (field at))))", "a[i][w.at]")
    ])
    func aNodeAndItsText(written: String, text: String) throws {
        // Given
        let node = try #require(try DatumReader().data(of: Array(written.unicodeScalars)).first)

        // When
        let rendered = try PathNode().text(of: node)
        let read = try PathNode().datum(of: text)

        // Then
        #expect(rendered == text)
        #expect(try DatumWriter().line(of: read) == written)
    }

    @Test("a path whose rendering reads back as another is refused", arguments: [
        "(path a)",
        "a.b",
        "`a[0]`",
        "(path a (field b.c))",
        "(path a (index `1`))",
        "(call f)"
    ])
    func anotherPathIsRefused(written: String) throws {
        // Given
        let node = try #require(try DatumReader().data(of: Array(written.unicodeScalars)).first)

        // When / Then
        #expect(throws: Unplaced.self) { try PathNode().text(of: node) }
    }

    @Test("a path no node writes is refused on the way out", arguments: ["?.a", "[0]", "a[ 0 ]", "a."])
    func aPathNoNodeWrites(text: String) {
        // When / Then
        #expect(throws: Unplaced.self) { try PathNode().datum(of: text) }
    }

    // MARK: - Public
    // MARK: - Private
}
