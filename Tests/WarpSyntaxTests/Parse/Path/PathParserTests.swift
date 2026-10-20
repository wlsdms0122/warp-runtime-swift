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
        #expect(parsed == [.name("items"), .index(0), .name("name"), .indexRef([.name("i")])])
    }

    @Test("a whole number between brackets is a whole number, whatever its size")
    func aBracketedWholeNumberIsNoName() throws {
        // Given
        let sut = PathParser()

        // When / Then. One no `Int` holds is refused, never read as a name
        #expect(try sut.parse("d[5]") == [.name("d"), .index(5)])
        #expect(throws: PathSyntaxError.self) { try sut.parse("d[99999999999999999999]") }
    }

    @Test("a path between brackets is a level deeper, and a path nests as deep as a document may")
    func aPathNestsToTheBound() throws {
        // Given
        let sut = PathParser()
        let nested = { (deep: Int) in
            String(repeating: "a[", count: deep - 1) + "i" + String(repeating: "]", count: deep - 1)
        }

        let literal = String(repeating: "a[", count: Value.nestingBound) + "0" + String(repeating: "]", count: Value.nestingBound)

        // When / Then. A whole number between brackets is no path
        #expect(try sut.parse(nested(Value.nestingBound)).rendered == nested(Value.nestingBound))
        #expect(try sut.parse(literal).rendered == literal)
        #expect(throws: PathSyntaxError.self) { try sut.parse(nested(Value.nestingBound + 1)) }
    }

    @Test("an optional dot parses and renders as itself")
    func optionalDotRoundTrips() throws {
        // Given
        let sut = PathParser()

        // When / Then. `?.` marks the segment after it
        #expect(
            try sut.parse("task?.name") == [.name("task"), .name("name", optional: true)]
        )
        #expect(
            try sut.parse("a.b?.c[0]?.d")
                == [.name("a"), .name("b"), .name("c", optional: true), .index(0), .name("d", optional: true)]
        )

        #expect(Path([.name("task"), .name("name", optional: true)]).rendered == "task?.name")

        // A space before the `?` belongs to nobody. The name comes out trimmed,
        // the way every other segment does.
        #expect(
            try sut.parse("a.b ?.c") == [.name("a"), .name("b"), .name("c", optional: true)]
        )
    }

    @Test("an optional bracket parses and renders as itself")
    func optionalBracketRoundTrips() throws {
        // Given
        let sut = PathParser()

        // When / Then. `?[` is the same mark `?.` puts on a name, on an index
        // instead: a literal, an index reference, one after an index
        #expect(
            try sut.parse("items?[0]") == [.name("items"), .index(0, optional: true)]
        )
        #expect(
            try sut.parse("a.items?[i]")
                == [.name("a"), .name("items"), .indexRef([.name("i")], optional: true)]
        )
        #expect(
            try sut.parse("rows[0]?[1]")
                == [.name("rows"), .index(0), .index(1, optional: true)]
        )

        // A mark on the head reads as written, for the load to refuse.
        #expect(try sut.parse("?[0]") == [.index(0, optional: true)])
        #expect(try sut.parse("?.a") == [.name("a", optional: true)])

        #expect(Path([.name("items"), .index(0, optional: true)]).rendered == "items?[0]")
        #expect(
            Path([.name("a"), .indexRef([.name("i")], optional: true)]).rendered == "a?[i]"
        )
    }

    @Test("a ? that marks nothing is refused")
    func danglingOptionalIsRefused() throws {
        // Given
        let sut = PathParser()

        // When / Then. A trailing `?` and a doubled `?` each claim an absence
        // no segment reads
        #expect(throws: PathSyntaxError.self) { try sut.parse("a.b?") }
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
            try sut.parse("items[0].name") == [.name("items"), .index(0), .name("name")]
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

        #expect(try sut.parse("a[i[0]]") == [.name("a"), .indexRef([.name("i"), .index(0)])])
    }

    @Test("a text between double quotes in the brackets parses and renders as itself")
    func aQuotedTextRoundTrips() throws {
        // Given
        let sut = PathParser()

        // When / Then. Inside the quotes a dot, a bracket and a space are the
        // text's, `\"` a quote and `\\` a backslash, and the empty text is a
        // text
        #expect(try sut.parse(#"d["a"]"#) == [.name("d"), .index("a")])
        #expect(try sut.parse(#"d[ "a.b[0] c" ]"#) == [.name("d"), .index("a.b[0] c")])
        #expect(try sut.parse(#"d["say \"hi\" \\"]"#) == [.name("d"), .index(#"say "hi" \"#)])
        #expect(try sut.parse(#"d[""]?["x"]"#) == [.name("d"), .index(""), .index("x", optional: true)])
        #expect(try sut.parse(#"d[k["a"]]"#) == [.name("d"), .indexRef([.name("k"), .index("a")])])

        for text in [#"d["a"]"#, #"d["say \"hi\" \\"]"#, #"d[""]?["x"]"#] {
            #expect(try sut.parse(text).rendered == text)
        }
    }

    @Test("a text between the brackets is closed, holds only itself and escapes two characters")
    func aQuotedTextIsRefusedWhereItIsNoText() throws {
        // Given
        let sut = PathParser()

        // When / Then
        #expect(throws: PathSyntaxError.self) { try sut.parse(#"d["a]"#) }
        #expect(throws: PathSyntaxError.self) { try sut.parse(#"d["a"b]"#) }
        #expect(throws: PathSyntaxError.self) { try sut.parse(#"d["a\n"]"#) }
    }

    // MARK: - Public
    // MARK: - Private
}
