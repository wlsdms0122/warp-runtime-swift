//
//  ReferenceLookupTests.swift
//  WarpTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

@Suite
struct ReferenceLookupTests {
    // MARK: - Property
    private let sut = Folding(bindings: [
                "name": .string("spec"),
                "run": .dictionary(["id": .string("r-1")]),
                "items": .array([.int(1), .int(2), .int(3)]),
                "step": .dictionary(["out": .string("done"), "list": .array([.string("a")])]),
                "index": .int(1)
            ], natives: Module.standard)

    // MARK: - Initializer
    // MARK: - Test
    @Test("an existing path returns its value")
    func existingPathReturnsValue() {
        #expect(sut.lookup([.key("name")]) == .found(.string("spec")))
        #expect(sut.lookup([.key("run"), .key("id")]) == .found(.string("r-1")))
        #expect(sut.lookup([.key("step"), .key("out")]) == .found(.string("done")))
        #expect(sut.lookup([.key("items"), .index(1)]) == .found(.int(2)))
    }

    @Test("a missing entry refuses, and ?. reads it as null")
    func missingEntryRefusesUnlessOptional() {
        // Then — absence past the head is a defect unless the author spelled
        // that they expect it
        guard case .unfit = sut.lookup([.key("step"), .key("gone")]) else {
            Issue.record("expected unfit for an absent entry")

            return
        }

        #expect(sut.lookup([.key("step"), .key("gone", optional: true)]) == .found(.null))
    }

    @Test("an index past the end is unfit, not absent")
    func indexPastTheEndIsUnfit() {
        // Then — the array is there and says how long it is, so a reading
        // that misses it read the length wrong
        guard case .unfit = sut.lookup([.key("items"), .index(9)]) else {
            Issue.record("expected unfit for an index past the end")

            return
        }
    }

    @Test("shape misuse is unfit, not absent")
    func shapeMisuseReturnsUnfit() {
        // Then — drilling a field into a string is an author error, not missing data
        guard case .unfit = sut.lookup([.key("name"), .key("foo")]) else {
            Issue.record("expected unfit")

            return
        }

        guard case .unfit = sut.lookup([.key("name"), .index(0)]) else {
            Issue.record("expected unfit for indexing into a string")

            return
        }
    }

    @Test("count derives where the link spelled a word")
    func countDerivesFromWordSegments() {
        #expect(sut.lookup([.key("items"), .word("count")]) == .found(.int(3)))
        #expect(sut.lookup([.key("name"), .word("count")]) == .found(.int(4)))
        #expect(sut.lookup([.key("step"), .word("count")]) == .found(.int(2)))
    }

    @Test("a key segment reads data alone, and never derives")
    func keySegmentDoesNotDerive() {
        // Then — the value has no say: a `key` the link left as a read is a
        // read, even where a word by that name would have answered
        guard case .unfit = sut.lookup([.key("items"), .key("count")]) else {
            Issue.record("expected unfit for a key on an array")

            return
        }

        guard case .unfit = sut.lookup([.key("name"), .key("count")]) else {
            Issue.record("expected unfit for a key on a string")

            return
        }
    }

    @Test("an index-reference segment resolves from a binding")
    func indexReferenceResolvesFromBinding() {
        #expect(sut.lookup([.key("items"), .indexRef([.key("index")])]) == .found(.int(2)))
    }

    @Test("a fraction index reference misses by the fact it is")
    func indexReferenceFractionNamesItsMiss() throws {
        // Given — a fraction with digits after the point, and a whole one no
        // machine word holds: two different facts, each named as itself
        let resolver = Folding(bindings: [
                    "items": .array([.int(1), .int(2)]),
                    "half": .double(1.5),
                    "far": .double(1e30)
                ], natives: Module.standard)

        guard case let .unfit(halfway) = resolver.lookup(
            [.key("items"), .indexRef([.key("half")])]
        ) else {
            Issue.record("expected unfit for a fractional index reference")

            return
        }

        #expect(halfway.contains("is not a whole number"))

        guard case let .unfit(distant) = resolver.lookup(
            [.key("items"), .indexRef([.key("far")])]
        ) else {
            Issue.record("expected unfit for an index reference past the word")

            return
        }

        #expect(distant.contains("indexes past the end of any array"))
    }

    @Test("an index reference that names nothing is unfit, not null")
    func indexReferenceNamingNothingIsUnfit() {
        // Then — the heads the text shows were checked at load, so a name
        // that answers nothing here is a defect said out loud
        guard case .unfit = sut.lookup([.key("items"), .indexRef([.key("typo")])]) else {
            Issue.record("expected unfit for an index reference naming nothing")

            return
        }
    }

}
