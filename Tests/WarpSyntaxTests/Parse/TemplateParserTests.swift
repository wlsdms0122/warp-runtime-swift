//
//  TemplateParserTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

@Suite
struct TemplateParserTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a mixed template splits into text and ref segments")
    func mixedTemplateSplitsRefsAndText() throws {
        // Given
        let sut = TemplateParser()

        // When
        let segments = try sut.parse("a=${x.y}, b=${z}")

        // Then
        #expect(segments == [
            .text("a="),
            .ref(path: [.key("x"), .key("y")]),
            .text(", b="),
            .ref(path: [.key("z")])
        ])
    }

    @Test("a doubled dollar escapes to a literal dollar")
    func doubledDollarEscapes() throws {
        // Given
        let sut = TemplateParser()

        // When
        let segments = try sut.parse("cost: $$5 and ${price}")

        // Then
        #expect(segments == [.text("cost: $5 and "), .ref(path: [.key("price")])])
    }

    @Test("a bracketed path parses into index segments")
    func bracketPathParsesIndexSegments() throws {
        // Given
        let sut = TemplateParser()

        // When
        let parsed = try sut.parseRefPath("items[0].name[${i}]")

        // Then
        #expect(parsed == [.key("items"), .index(0), .key("name"), .indexRef([.key("i")])])
    }

    @Test("an optional dot parses and renders as itself")
    func optionalDotRoundTrips() throws {
        // Given
        let sut = TemplateParser()

        // When / Then. `?.` marks the segment after it
        #expect(
            try sut.parseRefPath("task?.name") == [.key("task"), .key("name", optional: true)]
        )
        #expect(
            try sut.parseRefPath("a.b?.c[0]?.d")
                == [.key("a"), .key("b"), .key("c", optional: true), .index(0), .key("d", optional: true)]
        )

        #expect(Path([.key("task"), .key("name", optional: true)]).rendered == "task?.name")

        // A space before the `?` belongs to nobody. The name comes out trimmed,
        // the way every other segment does.
        #expect(
            try sut.parseRefPath("a.b ?.c") == [.key("a"), .key("b"), .key("c", optional: true)]
        )
    }

    @Test("an optional bracket parses and renders as itself")
    func optionalBracketRoundTrips() throws {
        // Given
        let sut = TemplateParser()

        // When / Then. `?[` is the same mark `?.` puts on a name, on an index
        // instead: a literal, an index reference, one after an index
        #expect(
            try sut.parseRefPath("items?[0]") == [.key("items"), .index(0, optional: true)]
        )
        #expect(
            try sut.parseRefPath("a.items?[i]")
                == [.key("a"), .key("items"), .indexRef([.key("i")], optional: true)]
        )
        #expect(
            try sut.parseRefPath("rows[0]?[1]")
                == [.key("rows"), .index(0), .index(1, optional: true)]
        )

        // The head is a name a scope holds, and `?[` at the head expects an
        // absence nothing stands before. Refused the way `?.` is there.
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath("?[0]") }

        #expect(Path([.key("items"), .index(0, optional: true)]).rendered == "items?[0]")
        #expect(
            Path([.key("a"), .indexRef([.key("i")], optional: true)]).rendered == "a?[i]"
        )
    }

    @Test("a ? that marks nothing is refused")
    func danglingOptionalIsRefused() throws {
        // Given
        let sut = TemplateParser()

        // Then. A trailing `?`, a `?` before the head, and a doubled `?` each
        // claim an absence no segment reads
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath("a.b?") }
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath("?.a") }
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath("a??.b") }
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath("a?b.c") }

        // An empty segment after `?.` is nothing to mark. Dropping it would
        // parse a path the author never wrote.
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath("a?..b") }
    }

    @Test("an empty segment is refused wherever it stands")
    func emptySegmentsAreRefused() throws {
        // Given. A silently dropped segment is a path the author never wrote,
        // `?.` or not
        let sut = TemplateParser()

        // Then
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath("a..b") }
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath("items[0]..name") }
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath(".a") }
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath("a.") }
        #expect(throws: TemplateSyntaxError.self) { try sut.parseRefPath("a.[0]") }

        // The dot after an index is a segment boundary, not an empty segment.
        #expect(
            try sut.parseRefPath("items[0].name") == [.key("items"), .index(0), .key("name")]
        )
    }

    @Test("render restores segments to the original text")
    func renderRoundTripsSegments() throws {
        // Given
        let sut = TemplateParser()
        let text = "a=${x.y[0]} $$ b"

        // When
        let rendered = sut.render(try sut.parse(text))

        // Then
        #expect(rendered == text)
    }

    // MARK: - Public
    // MARK: - Private
}
