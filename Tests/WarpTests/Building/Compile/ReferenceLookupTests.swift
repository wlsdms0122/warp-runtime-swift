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

@Suite("Reading a path")
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
        // When / Then
        await #expect(lookup([.name("name")], in: sut) == .found(.string("spec")))
        await #expect(lookup([.name("run"), .name("id")], in: sut) == .found(.string("r-1")))
        await #expect(lookup([.name("step"), .name("out")], in: sut) == .found(.string("done")))
        await #expect(lookup([.name("items"), .index(1)], in: sut) == .found(.int(2)))
    }

    @Test("a missing entry refuses, and ?. reads it as null")
    func missingEntryRefusesUnlessOptional() async {
        // When / Then. Absence past the head is a defect unless the author spelled
        // that they expect it
        guard case .unfit = await lookup([.name("step"), .name("gone")], in: sut) else {
            Issue.record("expected unfit for an absent entry")

            return
        }

        await #expect(lookup([.name("step"), .name("gone", optional: true)], in: sut) == .found(.null))
    }

    @Test("an index past the end is unfit, not absent")
    func indexPastTheEndIsUnfit() async {
        // When / Then. The array is there and says how long it is, so a reading that
        // misses it read the length wrong
        guard case .unfit = await lookup([.name("items"), .index(9)], in: sut) else {
            Issue.record("expected unfit for an index past the end")

            return
        }
    }

    @Test("type misuse is unfit, not absent")
    func typeMisuseReturnsUnfit() async {
        // When / Then. Drilling a field into a string is an author error, not missing
        // data
        guard case .unfit = await lookup([.name("name"), .name("foo")], in: sut) else {
            Issue.record("expected unfit")

            return
        }

        guard case .unfit = await lookup([.name("name"), .index(0)], in: sut) else {
            Issue.record("expected unfit for indexing into a String")

            return
        }
    }

    @Test("a key segment reads data alone, and never derives")
    func keySegmentDoesNotDerive() async {
        // When / Then. The value has no say: a `key` the build left as a read is a
        // read, even where a procedure by that name would have answered
        guard case .unfit = await lookup([.name("items"), .name("count")], in: sut) else {
            Issue.record("expected unfit for a key on an array")

            return
        }

        guard case .unfit = await lookup([.name("name"), .name("count")], in: sut) else {
            Issue.record("expected unfit for a key on a String")

            return
        }
    }

    @Test("an index-reference segment resolves from a binding")
    func indexReferenceResolvesFromBinding() async {
        // When / Then
        await #expect(lookup([.name("items"), .indexRef([.name("index")])], in: sut) == .found(.int(2)))
    }

    @Test("a fraction index reference is unfit")
    func indexReferenceFractionIsUnfit() async throws {
        // Given
        let folding = standard.folding([
            "items": .array([.int(1), .int(2)]),
            "half": .double(1.0)
        ])

        // When / Then. An index is an Int or a key, so a fraction is neither,
        // whole or not
        guard case let .unfit(reason) = await lookup(
            [.name("items"), .indexRef([.name("half")])],
            in: folding
        ) else {
            Issue.record("expected unfit for a fraction index reference")

            return
        }

        #expect(reason.contains("expected Int or String"))
    }

    @Test("an index reference that names nothing is unfit, not null")
    func indexReferenceNamingNothingIsUnfit() async {
        // When / Then. The heads the text shows were checked at load, so a name that
        // answers nothing here is a defect said out loud
        guard case .unfit = await lookup([.name("items"), .indexRef([.name("typo")])], in: sut) else {
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
