//
//  RecordTests.swift
//  Warp
//
//  Created by JSilver on 9/4/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A record holds its fields in name order")
struct RecordTests {
    @Test("entries stand in the byte order of their names whichever way they were given")
    func entriesAreOrderedByBytes() {
        // Given
        let byDictionary = Record(name: nil, ["b": .int(2), "a": .int(1), "c": .int(3)])
        let byEntries = Record(name: nil, entries: [(name: "c", value: .int(3)), (name: "a", value: .int(1)), (name: "b", value: .int(2))])

        // When / Then
        #expect(byDictionary.names == ["a", "b", "c"])
        #expect(byEntries.names == ["a", "b", "c"])
        #expect(byDictionary == byEntries)
        #expect(byDictionary.values == [.int(1), .int(2), .int(3)])
    }

    @Test("a field is found by its name, and a name not held answers nil")
    func aFieldIsFoundByName() {
        // Given
        let names = (0 ..< 40).map { index in "field\(index)" }
        let sut = Record(name: nil, entries: names.reversed().map { name in (name: name, value: .string(name)) })

        // When / Then
        for name in names {
            #expect(sut[name] == .string(name))
        }
        #expect(sut["field40"] == nil)
        #expect(sut[""] == nil)
        #expect(Record(name: nil, [:])["a"] == nil)
    }

    @Test("later entries under one name win over earlier ones")
    func laterEntriesWin() {
        // Given
        let sut = Record(name: nil, entries: [(name: "a", value: .int(1)), (name: "b", value: .int(2)), (name: "a", value: .int(3))])

        // When / Then
        #expect(sut.count == 2)
        #expect(sut["a"] == .int(3))
    }

    @Test("replacing writes a held name in place and puts a new one where it sorts")
    func replacingKeepsTheOrder() {
        // Given
        let sut = Record(name: "app.Point", ["a": .int(1), "c": .int(3)])

        // When
        let replaced = sut.replacing("c", with: .int(30))
        let inserted = sut.replacing("b", with: .int(2))
        let appended = sut.replacing("d", with: .int(4))

        // Then
        #expect(replaced.entries.map(\.value) == [.int(1), .int(30)])
        #expect(inserted.names == ["a", "b", "c"])
        #expect(appended.names == ["a", "c", "d"])
        #expect(inserted.name == "app.Point")
    }

    @Test("settling changes every value and nothing else")
    func settlingKeepsNamesAndOrder() throws {
        // Given
        let sut = Record(name: "app.Point", ["y": .int(2), "x": .int(1)])

        // When
        let doubled = try sut.settling { _, value in
            guard case let .int(number) = value else { throw ArgumentError("not a number") }

            return .int(number * 2)
        }

        // Then
        #expect(doubled.name == "app.Point")
        #expect(doubled.names == ["x", "y"])
        #expect(doubled.values == [.int(2), .int(4)])
    }

    @Test("two spellings Swift calls equal are two fields")
    func equivalentSpellingsAreTwoFields() {
        // Given
        let composed = "caf\u{E9}"
        let decomposed = "cafe\u{301}"

        // When
        let sut = Record(name: nil, entries: [(name: composed, value: .int(1)), (name: decomposed, value: .int(2))])

        // Then
        #expect(composed == decomposed)
        #expect(sut.count == 2)
        #expect(sut[composed] == .int(1))
        #expect(sut[decomposed] == .int(2))
    }

    @Test("a record equals another by name and by every entry, and matches across numeric width")
    func equalityAndMatching() {
        // Given
        let whole = Value.object(["a": .int(1), "b": .string("x")])
        let fraction = Value.object(["a": .double(1), "b": .string("x")])
        let named = Value.record(Record(name: "app.T", ["a": .int(1), "b": .string("x")]))

        // When / Then
        #expect(whole == Value.object(["b": .string("x"), "a": .int(1)]))
        #expect(whole != fraction)
        #expect(whole.matches(fraction))
        #expect(whole != named)
        #expect(!whole.matches(named))
        #expect(whole["a"] == .int(1))
        #expect(whole["z"] == nil)
    }
}
