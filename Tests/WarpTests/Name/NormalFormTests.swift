//
//  NormalFormTests.swift
//  WarpTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
@testable import Warp

// One name, one spelling. Unicode writes `é` two ways (one scalar, or `e` plus
// a combining mark) and the two look identical while comparing as different
// bytes. A name is normal form C or it is refused, so a declaration and a
// reference can only meet by being the same bytes.
//
// The rule is the type's: everything that holds a name holds a `Name`, so a
// program carrying a denormal spelling is a program nothing could build.
@Suite("A name is written in normal form C")
struct NormalFormTests {
    // MARK: - Property
    // `é` as `e` plus a combining acute. Canonically equivalent to the one-
    // scalar spelling, and different bytes.
    private let denormal = "cafe\u{301}"
    private let normal = "caf\u{E9}"

    // MARK: - Initializer
    // MARK: - Test
    @Test("a spelling outside normal form C is not a name")
    func aDenormalSpellingIsRefused() throws {
        // When / Then
        #expect(throws: NameRefused.self) {
            try Name(denormal)
        }
        #expect(try Name(normal).spelling == normal)
    }

    @Test("nothing written is no name")
    func anEmptySpellingIsRefused() {
        // Given. A name is what a declaration is called and what a reference
        // writes, and neither is written by writing nothing.
        let nothing = ""

        // When / Then
        #expect(throws: NameRefused.self) {
            try Name(nothing)
        }
    }

    @Test("names are ordered by their bytes")
    func namesAreOrderedByBytes() {
        // When / Then. The order a canonical writing puts fields in, and the
        // order a reader holds a document's keys to.
        #expect(("Z" as Name) < "a")
        #expect(("a" as Name) < "ab")
        #expect(!(("b" as Name) < "ab"))
    }

    @Test("a type's name is identifiers joined by dots, never a scalar's keyword nor a type the language names", arguments: [
        ("Account", true), ("Bank.Account", true), ("_x1", true), ("Int.Range", true),
        ("true", false), ("Bank.null", true), ("", false), ("a..b", false), ("foo-bar", false), ("café", false),
        ("Int", false), ("Array", false), ("Self", false), ("consuming Int", false)
    ])
    func aTypeNameIsIdentifiersJoinedByDots(name: String, holds: Bool) {
        // When / Then
        #expect(((try? Name(name))?.isDeclarable ?? false) == holds)
    }

    // MARK: - Public
    // MARK: - Private
}
