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
    // What a path holds, or why the reading went wrong.
    private enum Lookup: Equatable {
        case found(Value)
        case unfit(reason: String)
    }

    // MARK: - Property
    private let standard: Image
    private let sut: Folding

    // MARK: - Initializer
    init() async throws {
        standard = try await Builder().build(Module.standard)
        sut = standard.folding([
            "name": .string("spec"),
            "run": .dictionary(["id": .string("r-1")]),
            "items": .array([.int(1), .int(2), .int(3)]),
            "step": .dictionary(["out": .string("done"), "list": .array([.string("a")])]),
            "index": .int(1)
        ])
    }

    // MARK: - Test
    @Test("an existing path returns its value")
    func existingPathReturnsValue() async {
        await #expect(lookup([.key("name")], in: sut) == .found(.string("spec")))
        await #expect(lookup([.key("run"), .key("id")], in: sut) == .found(.string("r-1")))
        await #expect(lookup([.key("step"), .key("out")], in: sut) == .found(.string("done")))
        await #expect(lookup([.key("items"), .index(1)], in: sut) == .found(.int(2)))
    }

    @Test("a missing entry refuses, and ?. reads it as null")
    func missingEntryRefusesUnlessOptional() async {
        // Then. Absence past the head is a defect unless the author spelled
        // that they expect it
        guard case .unfit = await lookup([.key("step"), .key("gone")], in: sut) else {
            Issue.record("expected unfit for an absent entry")

            return
        }

        await #expect(lookup([.key("step"), .key("gone", optional: true)], in: sut) == .found(.null))
    }

    @Test("an index past the end is unfit, not absent")
    func indexPastTheEndIsUnfit() async {
        // Then. The array is there and says how long it is, so a reading that
        // misses it read the length wrong
        guard case .unfit = await lookup([.key("items"), .index(9)], in: sut) else {
            Issue.record("expected unfit for an index past the end")

            return
        }
    }

    @Test("type misuse is unfit, not absent")
    func typeMisuseReturnsUnfit() async {
        // Then. Drilling a field into a string is an author error, not missing
        // data
        guard case .unfit = await lookup([.key("name"), .key("foo")], in: sut) else {
            Issue.record("expected unfit")

            return
        }

        guard case .unfit = await lookup([.key("name"), .index(0)], in: sut) else {
            Issue.record("expected unfit for indexing into a string")

            return
        }
    }

    @Test("a key segment reads data alone, and never derives")
    func keySegmentDoesNotDerive() async {
        // Then. The value has no say: a `key` the build left as a read is a
        // read, even where a procedure by that name would have answered
        guard case .unfit = await lookup([.key("items"), .key("count")], in: sut) else {
            Issue.record("expected unfit for a key on an array")

            return
        }

        guard case .unfit = await lookup([.key("name"), .key("count")], in: sut) else {
            Issue.record("expected unfit for a key on a string")

            return
        }
    }

    @Test("an index-reference segment resolves from a binding")
    func indexReferenceResolvesFromBinding() async {
        await #expect(lookup([.key("items"), .indexRef([.key("index")])], in: sut) == .found(.int(2)))
    }

    @Test("a fraction index reference misses by the fact it is")
    func indexReferenceFractionNamesItsMiss() async throws {
        // Given. A fraction with digits after the point, and a whole one no
        // an int holds: two different facts, each named as itself
        let folding = standard.folding([
            "items": .array([.int(1), .int(2)]),
            "half": .double(1.5),
            "far": .double(1e30)
        ])

        guard case let .unfit(halfway) = await lookup(
            [.key("items"), .indexRef([.key("half")])],
            in: folding
        ) else {
            Issue.record("expected unfit for a fractional index reference")

            return
        }

        #expect(halfway.contains("is not a whole number"))

        guard case let .unfit(distant) = await lookup(
            [.key("items"), .indexRef([.key("far")])],
            in: folding
        ) else {
            Issue.record("expected unfit for an index reference past the int")

            return
        }

        #expect(distant.contains("indexes past the end of any array"))
    }

    @Test("an index reference that names nothing is unfit, not null")
    func indexReferenceNamingNothingIsUnfit() async {
        // Then. The heads the text shows were checked at load, so a name that
        // answers nothing here is a defect said out loud
        guard case .unfit = await lookup([.key("items"), .indexRef([.key("typo")])], in: sut) else {
            Issue.record("expected unfit for an index reference naming nothing")

            return
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func lookup(_ path: Path, in folding: Folding) async -> Lookup {
        do {
            return .found(try await folding.read(path, at: .given("test")))
        } catch let unfit as ReferenceUnfit {
            return .unfit(reason: unfit.reason)
        } catch {
            return .unfit(reason: "\(error)")
        }
    }
}
