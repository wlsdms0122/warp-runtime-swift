//
//  DatumWriterTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax

// The one layout, and a name written bare only where it reads back bare.
@Suite("The datum writer")
struct DatumWriterTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a block holding a list breaks, and so does whatever holds one that breaks")
    func aBlockBreaks() throws {
        // Given
        let block = Datum.block("loop", [.node("while", [.name("c")]), .block("body", [.node("set", [.name("x"), Datum(.int(1))])])])
        let data: [Datum] = [
            .node("warp", [Datum(.int(1))]),
            .node("let", [.name("w"), block]),
            .block("body"),
            .node("a", [.node("b", [.node("c")])])
        ]

        // When
        let sut = try DatumWriter().text(of: data)

        // Then
        #expect(sut == """
        (warp 1)

        (let w
          (loop
            (while c)
            (body
              (set x 1))))
        (body)
        (a (b (c)))

        """)
    }

    @Test("a name is written bare where it reads back bare, and in backticks otherwise")
    func aNameReadsBack() throws {
        // Given
        let names = ["x", "App.g", "as?", "null", "1a", "-1", "a b", "a(", "a\"", "a`b", "\u{1}", "-", "+x"]

        // When
        let written = try names.map { name in try DatumWriter().line(of: .name(name)) }

        // Then
        #expect(written == ["x", "App.g", "as?", "`null`", "`1a`", "`-1`", "`a b`", "`a(`", "`a\"`", "`a\\`b`", "`\\u0001`", "-", "+x"])

        for (name, text) in zip(names, written) {
            #expect(try DatumReader().data(of: Array(text.unicodeScalars)).first.flatMap { datum in
                guard case let .name(read) = datum.form else { return nil }

                return read
            } == name)
        }
    }

    @Test("a list past the reader's bound is refused on the way out")
    func pastTheBoundIsRefused() {
        // Given
        let deep = (0 ..< DatumReader.nestingBound).reduce(Datum.node("a")) { held, _ in .node("a", [held]) }

        // When / Then
        #expect(throws: Unplaced.self) { try DatumWriter().text(of: [deep]) }
    }

    // MARK: - Public
    // MARK: - Private
}
