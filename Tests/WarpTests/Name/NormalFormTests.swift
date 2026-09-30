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
        #expect(throws: NameRefused.self) {
            try Name(denormal)
        }
        #expect(try Name(normal).spelling == normal)
    }

    @Test("nothing written is no name")
    func anEmptySpellingIsRefused() {
        // A name is what a declaration is called and what a reference writes,
        // and neither is written by writing nothing.
        let nothing = ""

        #expect(throws: NameRefused.self) {
            try Name(nothing)
        }
    }

    @Test("names are ordered by their bytes")
    func namesAreOrderedByBytes() throws {
        // The order a canonical writing puts fields in, and the order a
        // reader holds a document's keys to.
        #expect(try Name("Z") < Name("a"))
        #expect(try Name("a") < Name("ab"))
        #expect(try !(Name("b") < Name("ab")))
    }

    @Test("a type's name is identifiers joined by dots, and never a scalar's keyword", arguments: [
        ("Account", true), ("bank.Account", true), ("_x1", true),
        ("true", false), ("bank.null", true), ("", false), ("a..b", false), ("foo-bar", false), ("café", false)
    ])
    func aTypeNameIsIdentifiersJoinedByDots(name: String, holds: Bool) {
        #expect(((try? Name(name))?.isDeclarable ?? false) == holds)
    }

    // MARK: - Public
    // MARK: - Private
}
