//
//  PathParserTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

@Suite("A path parses into segments")
struct PathParserTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a bracketed path parses into index segments")
    func bracketPathParsesIndexSegments() throws {
        // Given
        let sut = PathParser()

        // When
        let parsed = try sut.parse("items[0].name[${i}]")

        // Then
        #expect(parsed == [.key("items"), .index(0), .key("name"), .indexRef([.key("i")])])
    }

    @Test("a whole number between brackets is a position, whatever its size")
    func aBracketedWholeNumberIsNoName() throws {
        // Given
        let sut = PathParser()

        // When / Then. One no `Int` holds is refused, never read as a name
        #expect(try sut.parse("d[5]") == [.key("d"), .index(5)])
        #expect(throws: PathSyntaxError.self) { try sut.parse("d[99999999999999999999]") }
    }

    @Test("an optional dot parses and renders as itself")
    func optionalDotRoundTrips() throws {
        // Given
        let sut = PathParser()

        // When / Then. `?.` marks the segment after it
        #expect(
            try sut.parse("task?.name") == [.key("task"), .key("name", optional: true)]
        )
        #expect(
            try sut.parse("a.b?.c[0]?.d")
                == [.key("a"), .key("b"), .key("c", optional: true), .index(0), .key("d", optional: true)]
        )

        #expect(Path([.key("task"), .key("name", optional: true)]).rendered == "task?.name")

        // A space before the `?` belongs to nobody. The name comes out trimmed,
        // the way every other segment does.
        #expect(
            try sut.parse("a.b ?.c") == [.key("a"), .key("b"), .key("c", optional: true)]
        )
    }

    @Test("an optional bracket parses and renders as itself")
    func optionalBracketRoundTrips() throws {
        // Given
        let sut = PathParser()

        // When / Then. `?[` is the same mark `?.` puts on a name, on an index
        // instead: a literal, an index reference, one after an index
        #expect(
            try sut.parse("items?[0]") == [.key("items"), .index(0, optional: true)]
        )
        #expect(
            try sut.parse("a.items?[i]")
                == [.key("a"), .key("items"), .indexRef([.key("i")], optional: true)]
        )
        #expect(
            try sut.parse("rows[0]?[1]")
                == [.key("rows"), .index(0), .index(1, optional: true)]
        )

        // The head is a name a scope holds, and `?[` at the head expects an
        // absence nothing stands before. Refused the way `?.` is there.
        #expect(throws: PathSyntaxError.self) { try sut.parse("?[0]") }

        #expect(Path([.key("items"), .index(0, optional: true)]).rendered == "items?[0]")
        #expect(
            Path([.key("a"), .indexRef([.key("i")], optional: true)]).rendered == "a?[i]"
        )
    }

    @Test("a ? that marks nothing is refused")
    func danglingOptionalIsRefused() throws {
        // Given
        let sut = PathParser()

        // When / Then. A trailing `?`, a `?` before the head, and a doubled `?`
        // each claim an absence no segment reads
        #expect(throws: PathSyntaxError.self) { try sut.parse("a.b?") }
        #expect(throws: PathSyntaxError.self) { try sut.parse("?.a") }
        #expect(throws: PathSyntaxError.self) { try sut.parse("a??.b") }
        #expect(throws: PathSyntaxError.self) { try sut.parse("a?b.c") }

        // And. An empty segment after `?.` is nothing to mark. Dropping it
        // would parse a path the author never wrote.
        #expect(throws: PathSyntaxError.self) { try sut.parse("a?..b") }
    }

    @Test("an empty segment is refused wherever it stands")
    func emptySegmentsAreRefused() throws {
        // Given. A silently dropped segment is a path the author never wrote,
        // `?.` or not
        let sut = PathParser()

        // When / Then
        #expect(throws: PathSyntaxError.self) { try sut.parse("a..b") }
        #expect(throws: PathSyntaxError.self) { try sut.parse("items[0]..name") }
        #expect(throws: PathSyntaxError.self) { try sut.parse(".a") }
        #expect(throws: PathSyntaxError.self) { try sut.parse("a.") }
        #expect(throws: PathSyntaxError.self) { try sut.parse("a.[0]") }

        // And. The dot after an index is a segment boundary, not an empty
        // segment.
        #expect(
            try sut.parse("items[0].name") == [.key("items"), .index(0), .key("name")]
        )
    }

    @Test("a bracket is closed, and closes one opened before it")
    func unbalancedBracketsAreRefused() throws {
        // Given
        let sut = PathParser()

        // When / Then. Neither bracket is folded into a name
        #expect(throws: PathSyntaxError.self) { try sut.parse("a[0") }
        #expect(throws: PathSyntaxError.self) { try sut.parse("a[i[0]") }
        #expect(throws: PathSyntaxError.self) { try sut.parse("a]") }
        #expect(throws: PathSyntaxError.self) { try sut.parse("a[0]]") }

        #expect(try sut.parse("a[i[0]]") == [.key("a"), .indexRef([.key("i"), .index(0)])])
    }

    // MARK: - Public
    // MARK: - Private
}
