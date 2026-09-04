//
//  RecordTests.swift
//  Warp
//
//  Created by JSilver on 9/4/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A record stands on the layout it was made with")
struct RecordTests {
    // MARK: - Test
    @Test("a layout orders its fields by their names' bytes whichever way they were given")
    func aLayoutIsOrderedByBytes() {
        // Given
        let sut = Layout(fields: ["b", "a", "c"])

        // When / Then
        #expect(sut.fields == ["a", "b", "c"])
        #expect(sut.position(of: "b") == 1)
        #expect(sut.position(of: "z") == nil)
    }

    @Test("a record built from fields holds them at their layout's places")
    func fieldsStandWhereTheLayoutPutsThem() {
        // Given
        let sut = Record(name: nil, ["b": .int(2), "a": .int(1), "c": .int(3)])

        // When / Then
        #expect(sut.names == ["a", "b", "c"])
        #expect(sut.values == [.int(1), .int(2), .int(3)])
        #expect(sut["b"] == .int(2))
        #expect(sut["z"] == nil)
    }

    @Test("a layout handed the wrong number of values is refused")
    func aLayoutIsFilledExactly() throws {
        // Given
        let layout = Layout(fields: ["a", "b"])

        // When / Then
        #expect(try Record(layout: layout, checking: [.int(1), .int(2)]).values == [.int(1), .int(2)])
        #expect(throws: ValueRefused.self) { try Record(layout: layout, checking: [.int(1)]) }
        #expect(throws: ValueRefused.self) { try Record(layout: layout, checking: [.int(1), .int(2), .int(3)]) }
    }

    @Test("a field the layout does not name is refused rather than made")
    func aFieldOutsideTheLayoutIsRefused() throws {
        // Given
        let sut = Record(name: "app.Point", ["a": .int(1), "c": .int(3)])

        // When / Then
        #expect(try sut.writing("c", with: .int(30)).values == [.int(1), .int(30)])
        #expect(throws: ValueRefused.self) { try sut.writing("b", with: .int(2)) }
    }

    @Test("a record's name is part of its layout")
    func aNameIsPartOfTheLayout() {
        // Given
        let sut = Record(name: "app.Point", ["a": .int(1)])

        // When / Then
        #expect(sut.name == "app.Point")
        #expect(sut.named(nil).name == nil)
        #expect(sut != Record(name: nil, ["a": .int(1)]))
        #expect(sut != Record(name: "app.Vault", ["a": .int(1)]))
    }

    @Test("a record's own name is compared as bytes, the way its fields are")
    func aNameIsComparedAsBytes() throws {
        // Given
        let composed = Record(name: "app.Caf\u{E9}", ["a": .int(1)])
        let decomposed = "app.Cafe\u{301}"

        // When / Then — the decomposed spelling is no name, so there is no
        // second record to compare with
        #expect(throws: NameRefused.self) { try Name(decomposed) }
        #expect(composed.name?.spelling == "app.Caf\u{E9}")
    }

    @Test("mapping values changes every value and nothing else")
    func mappingValuesKeepsTheLayout() throws {
        // Given
        let sut = Record(name: "app.Point", ["y": .int(2), "x": .int(1)])

        // When
        let doubled = try sut.mapValues { _, value in
            guard case let .int(number) = value else { throw ArgumentError("not a number") }

            return .int(number * 2)
        }

        // Then
        #expect(doubled.layout == sut.layout)
        #expect(doubled.values == [.int(2), .int(4)])
    }

    @Test("a nameless record and a dictionary of the same fields are one value")
    func aNamelessRecordEqualsADictionary() {
        // Given
        let record = Value.record(Record(name: nil, ["a": .int(1), "b": .string("x")]))
        let named = Value.record(Record(name: "app.T", ["a": .int(1), "b": .string("x")]))
        let dictionary = Value.dictionary(["a": .int(1), "b": .string("x")])

        // When / Then
        #expect(record == dictionary)
        #expect(named != dictionary)
        #expect(record.matches(.dictionary(["a": .double(1), "b": .string("x")])))
        #expect(record["a"] == .int(1))
    }
}
