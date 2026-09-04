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
    func aFieldIsFoundByName() throws {
        // Given
        let names = try (0 ..< 40).map { index in try Name("field\(index)") }
        let sut = Record(name: nil, entries: names.reversed().map { name in (name: name, value: Value.string(name.spelling)) })

        // When / Then
        for name in names {
            #expect(sut[name] == .string(name.spelling))
        }
        #expect(sut["field40"] == nil)
        #expect(sut["held"] == nil)
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

    @Test("writing a field replaces a held one in place and puts a new one where it sorts")
    func writingKeepsTheOrder() {
        // Given
        let sut = Record(name: "app.Point", ["a": .int(1), "c": .int(3)])

        // When
        let replaced = sut.writing("c", with: .int(30))
        let inserted = sut.writing("b", with: .int(2))
        let appended = sut.writing("d", with: .int(4))

        // Then
        #expect(replaced.entries.map(\.value) == [.int(1), .int(30)])
        #expect(inserted.names == ["a", "b", "c"])
        #expect(appended.names == ["a", "c", "d"])
        #expect(inserted.name == "app.Point")
    }

    @Test("removing takes a held field out and leaves a record without it as it is")
    func removingAField() {
        // Given
        let sut = Record(name: "app.Point", ["a": .int(1), "b": .int(2)])

        // When / Then
        #expect(sut.removing("a").names == ["b"])
        #expect(sut.removing("z") == sut)
        #expect(sut.removing("a").name == "app.Point")
    }

    @Test("setting a field answers a new record, whatever name the receiver had")
    func settingAnswersARecord() throws {
        // Given
        let question = Question(
            receiver: .record(Record(name: "app.Point", ["a": .int(1)])),
            arguments: ["key": .string("b"), "value": .int(2)]
        )

        // When
        let answer = try MappingQuery(.setting).evaluate(question)

        // Then
        #expect(answer == .record(["a": .int(1), "b": .int(2)]))
    }

    @Test("mapping values changes every value and nothing else")
    func mappingValuesKeepsNamesAndOrder() throws {
        // Given
        let sut = Record(name: "app.Point", ["y": .int(2), "x": .int(1)])

        // When
        let doubled = try sut.mapValues { _, value in
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
        let composed: Name = "caf\u{E9}"
        let decomposed = "cafe\u{301}"

        // When / Then — the decomposed spelling is not a name, so a record
        // holding both is a record nothing can build
        #expect(composed.spelling == decomposed)
        #expect(throws: NameRefused.self) { try Name(decomposed) }
    }

    @Test("a record's own name is compared as bytes, the way its fields are")
    func aNameIsComparedAsBytes() throws {
        // Given
        let composed = Record(name: "app.Caf\u{E9}", ["a": .int(1)])
        let decomposed = "app.Cafe\u{301}"

        // When / Then — the decomposed spelling is no name, so there is no
        // second record to compare with
        #expect(throws: NameRefused.self) { try Name(decomposed) }
        #expect(Record(name: nil, ["a": .int(1)]) != composed)
        #expect(composed != Record(name: "app.Vault", ["a": .int(1)]))
    }

    @Test("a name a caller assembles in Swift is held to normal form C")
    func aCallerIsHeldToNormalForm() {
        // A caller reaches a record's fields and its name through `Name`, so
        // a spelling that is not one is refused where it is written rather
        // than at whatever later reads it.
        let decomposed = "cafe\u{301}"

        #expect(throws: NameRefused.self) { try Name(decomposed) }
    }

    @Test("setting refuses a key that is not one byte spelling")
    func settingRefusesAKeyOutsideNormalForm() {
        // Given
        let question = Question(
            receiver: .record(["a": .int(1)]),
            arguments: ["key": .string("cafe\u{301}"), "value": .int(2)]
        )

        // When / Then
        #expect {
            try MappingQuery(.setting).evaluate(question)
        } throws: { error in
            "\(error)".contains("normal form C")
        }
    }

    @Test("a record equals another by name and by every entry, and matches across numeric width")
    func equalityAndMatching() {
        // Given
        let whole = Value.record(["a": .int(1), "b": .string("x")])
        let fraction = Value.record(["a": .double(1), "b": .string("x")])
        let named = Value.record(Record(name: "app.T", ["a": .int(1), "b": .string("x")]))

        // When / Then
        #expect(whole == Value.record(["b": .string("x"), "a": .int(1)]))
        #expect(whole != fraction)
        #expect(whole.matches(fraction))
        #expect(whole != named)
        #expect(!whole.matches(named))
        #expect(whole["a"] == .int(1))
        #expect(whole["z"] == nil)
    }
}
