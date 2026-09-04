//
//  NormalFormTests.swift
//  WarpTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
@testable import Warp

// One name, one spelling. Unicode writes `é` two ways — one scalar, or `e` plus
// a combining mark — and the two look identical while comparing as different
// bytes. A name is normal form C or it is refused, so a declaration and a
// reference can only meet by being the same bytes.
//
// The rule is the type's: everything that holds a name holds a `Name`, so a
// program carrying a denormal spelling is a program nothing could build.
@Suite("A name is written in normal form C")
struct NormalFormTests {
    // MARK: - Property
    // `é` as `e` plus a combining acute — canonically equivalent to the one-
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

    @Test("names are equal by their bytes, not by canonical equivalence")
    func namesAreEqualByBytes() throws {
        // Swift calls the two spellings one string. A name is not a string.
        #expect(normal == denormal)
        #expect(try Name(normal) != Name("cafe"))
        #expect(try Name(normal) == Name(normal))
    }

    @Test("names are ordered by their bytes")
    func namesAreOrderedByBytes() throws {
        // The order a canonical writing puts fields in, and the order a
        // reader holds a document's keys to.
        #expect(try Name("Z") < Name("a"))
        #expect(try Name("a") < Name("ab"))
        #expect(try !(Name("b") < Name("ab")))
    }

    @Test("a dotted name is unqualified to its last segment")
    func aDottedNameIsUnqualified() throws {
        #expect(try Name("std.logic.equal").unqualified == Name("equal"))
        #expect(try Name("equal").unqualified == Name("equal"))
    }

    @Test("a type's name is identifiers joined by dots, and never a scalar's word")
    func aTypesNameIsDeclarable() throws {
        #expect(try Name("std.logic.Answer").isDeclarable)
        #expect(try !Name("std..Answer").isDeclarable)
        #expect(try !Name("a name").isDeclarable)
        #expect(try !Name("true").isDeclarable)
    }

    @Test("a name a program writes as a value carries the rule with it")
    func aRecordHoldsNames() throws {
        // A record's keys and its own name are names, so the record cannot be
        // the place a denormal spelling gets in.
        let record = Record(name: try Name(normal), [try Name(normal): .int(1)])

        #expect(record.name?.spelling == normal)
        #expect(record[try Name(normal)] == .int(1))
    }

    // MARK: - Public
    // MARK: - Private
}
